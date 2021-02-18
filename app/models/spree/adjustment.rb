# frozen_string_literal: true

require 'spree/localized_number'
require 'concerns/adjustment_scopes'

# Adjustments represent a change to the +item_total+ of an Order. Each adjustment
# has an +amount+ that can be either positive or negative.
#
# Adjustments can be open/closed/finalized
#
# Once an adjustment is finalized, it cannot be changed, but an adjustment can
# toggle between open/closed as needed
#
# Boolean attributes:
#
# +mandatory+
#
# If this flag is set to true then it means the the charge is required and will not
# be removed from the order, even if the amount is zero. In other words a record
# will be created even if the amount is zero. This is useful for representing things
# such as shipping and tax charges where you may want to make it explicitly clear
# that no charge was made for such things.
#
# +eligible?+
#
# This boolean attributes stores whether this adjustment is currently eligible
# for its order. Only eligible adjustments count towards the order's adjustment
# total. This allows an adjustment to be preserved if it becomes ineligible so
# it might be reinstated.
module Spree
  class Adjustment < ActiveRecord::Base
    extend Spree::LocalizedNumber

    # Deletion of metadata is handled in the database.
    # So we don't need the option `dependent: :destroy` as long as
    # AdjustmentMetadata has no destroy logic itself.
    has_one :metadata, class_name: 'AdjustmentMetadata'

    belongs_to :adjustable, polymorphic: true
    belongs_to :source, polymorphic: true
    belongs_to :originator, polymorphic: true
    belongs_to :order, class_name: "Spree::Order"

    belongs_to :tax_rate, -> { where spree_adjustments: { originator_type: 'Spree::TaxRate' } },
               foreign_key: 'originator_id'

    validates :label, presence: true
    validates :amount, numericality: true

    after_save :update_adjustable
    after_destroy :update_adjustable

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end

      event :finalize do
        transition from: [:open, :closed], to: :finalized
      end
    end

    scope :tax, -> { where(originator_type: 'Spree::TaxRate') }
    scope :price, -> { where(adjustable_type: 'Spree::LineItem') }
    scope :optional, -> { where(mandatory: false) }
    scope :charge, -> { where('amount >= 0') }
    scope :credit, -> { where('amount < 0') }
    scope :return_authorization, -> { where(source_type: "Spree::ReturnAuthorization") }
    scope :inclusive, -> { where(included: true) }
    scope :additional, -> { where(included: false) }

    scope :enterprise_fee, -> { where(originator_type: 'EnterpriseFee') }
    scope :admin,          -> { where(source_type: nil, originator_type: nil) }
    scope :included_tax,   -> {
      where(originator_type: 'Spree::TaxRate', adjustable_type: 'Spree::LineItem')
    }

    scope :with_tax,       -> { where('spree_adjustments.included_tax <> 0') }
    scope :without_tax,    -> { where('spree_adjustments.included_tax = 0') }
    scope :payment_fee,    -> { where(AdjustmentScopes::PAYMENT_FEE_SCOPE) }
    scope :shipping,       -> { where(AdjustmentScopes::SHIPPING_SCOPE) }
    scope :eligible,       -> { where(AdjustmentScopes::ELIGIBLE_SCOPE) }

    localize_number :amount

    # Update the boolean _eligible_ attribute which determines which adjustments
    # count towards the order's adjustment_total.
    def set_eligibility
      result = mandatory || amount != 0
      update_columns(
        eligible: result,
        updated_at: Time.zone.now
      )
    end

    # Update both the eligibility and amount of the adjustment. Adjustments
    # delegate updating of amount to their Originator when present, but only if
    # +locked+ is false. Adjustments that are +locked+ will never change their amount.
    #
    # Adjustments delegate updating of amount to their Originator when present,
    # but only if when they're in "open" state, closed or finalized adjustments
    # are not recalculated.
    #
    # It receives +calculable+ as the updated source here so calculations can be
    # performed on the current values of that source. If we used +source+ it
    # could load the old record from db for the association. e.g. when updating
    # more than on line items at once via accepted_nested_attributes the order
    # object on the association would be in a old state and therefore the
    # adjustment calculations would not performed on proper values
    def update!(calculable = nil)
      return if immutable?

      # Fix for Spree issue #3381
      # If we attempt to call 'source' before the reload, then source is currently
      # the order object. After calling a reload, the source is the Shipment.
      reload
      originator.update_adjustment(self, calculable || source) if originator.present?
      set_eligibility
    end

    def currency
      adjustable ? adjustable.currency : Spree::Config[:currency]
    end

    def display_amount
      Spree::Money.new(amount, currency: currency)
    end

    def immutable?
      state != "open"
    end

    def set_included_tax!(rate)
      tax = amount - (amount / (1 + rate))
      set_absolute_included_tax! tax
    end

    def set_absolute_included_tax!(tax)
      # This rubocop issue can now fixed by renaming Adjustment#update! to something else,
      #   then AR's update! can be used instead of update_attributes!
      # rubocop:disable Rails/ActiveRecordAliases
      update_attributes! included_tax: tax.round(2)
      # rubocop:enable Rails/ActiveRecordAliases
    end

    def display_included_tax
      Spree::Money.new(included_tax, currency: currency)
    end

    def has_tax?
      included_tax.positive?
    end

    def self.without_callbacks
      skip_callback :save, :after, :update_adjustable
      skip_callback :destroy, :after, :update_adjustable

      result = yield
    ensure
      set_callback :save, :after, :update_adjustable
      set_callback :destroy, :after, :update_adjustable

      result
    end

    # Allow accessing soft-deleted originator objects
    def originator
      return if originator_type.blank?

      originator_type.constantize.unscoped { super }
    end

    private

    def update_adjustable
      adjustable.update! if adjustable.is_a? Order
    end
  end
end
