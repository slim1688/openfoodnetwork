# frozen_string_literal: true

require 'open_food_network/enterprise_fee_calculator'
require 'variant_units/variant_and_line_item_naming'
require 'concerns/variant_stock'
require 'spree/localized_number'

module Spree
  class Variant < ActiveRecord::Base
    extend Spree::LocalizedNumber
    include VariantUnits::VariantAndLineItemNaming
    include VariantStock

    acts_as_paranoid

    belongs_to :product, touch: true, class_name: 'Spree::Product'
    delegate_belongs_to :product, :name, :description, :permalink, :available_on,
                        :tax_category_id, :shipping_category_id, :meta_description,
                        :meta_keywords, :tax_category, :shipping_category

    has_many :inventory_units, inverse_of: :variant
    has_many :line_items, inverse_of: :variant

    has_many :stock_items, dependent: :destroy, inverse_of: :variant
    has_many :stock_locations, through: :stock_items
    has_many :stock_movements

    has_and_belongs_to_many :option_values, join_table: :spree_option_values_variants

    has_many :images, -> { order(:position) }, as: :viewable,
                                               dependent: :destroy,
                                               class_name: "Spree::Image"
    accepts_nested_attributes_for :images

    has_one :default_price,
            -> { where currency: Spree::Config[:currency] },
            class_name: 'Spree::Price',
            dependent: :destroy
    has_many :prices,
             class_name: 'Spree::Price',
             dependent: :destroy
    delegate_belongs_to :default_price, :display_price, :display_amount,
                        :price, :price=, :currency

    has_many :exchange_variants
    has_many :exchanges, through: :exchange_variants
    has_many :variant_overrides
    has_many :inventory_items

    localize_number :price, :cost_price, :weight

    validate :check_price
    validates :price, numericality: { greater_than_or_equal_to: 0 },
                      presence: true,
                      if: proc { Spree::Config[:require_master_price] }
    validates :cost_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

    validates :unit_value, presence: true, if: ->(variant) {
      %w(weight volume).include?(variant.product.andand.variant_unit)
    }

    validates :unit_description, presence: true, if: ->(variant) {
      variant.product.andand.variant_unit.present? && variant.unit_value.nil?
    }

    before_validation :set_cost_currency
    before_validation :update_weight_from_unit_value, if: ->(v) { v.product.present? }
    before_validation :ensure_unit_value

    after_save :save_default_price
    after_save :update_units

    after_create :create_stock_items
    after_create :set_position

    around_destroy :destruction

    # default variant scope only lists non-deleted variants
    scope :deleted, lambda { where('deleted_at IS NOT NULL') }

    scope :with_order_cycles_inner, -> { joins(exchanges: :order_cycle) }

    scope :not_master, -> { where(is_master: false) }
    scope :in_order_cycle, lambda { |order_cycle|
      with_order_cycles_inner.
        merge(Exchange.outgoing).
        where('order_cycles.id = ?', order_cycle).
        select('DISTINCT spree_variants.*')
    }

    scope :in_schedule, lambda { |schedule|
      joins(exchanges: { order_cycle: :schedules }).
        merge(Exchange.outgoing).
        where(schedules: { id: schedule }).
        select('DISTINCT spree_variants.*')
    }

    scope :for_distribution, lambda { |order_cycle, distributor|
      where('spree_variants.id IN (?)', order_cycle.variants_distributed_by(distributor).
        select(&:id))
    }

    scope :visible_for, lambda { |enterprise|
      joins(:inventory_items).
        where(
          'inventory_items.enterprise_id = (?) AND inventory_items.visible = (?)',
          enterprise,
          true
        )
    }

    scope :not_hidden_for, lambda { |enterprise|
      return where("1=0") if enterprise.blank?

      joins("
        LEFT OUTER JOIN (SELECT *
                           FROM inventory_items
                           WHERE enterprise_id = #{sanitize enterprise.andand.id})
          AS o_inventory_items
          ON o_inventory_items.variant_id = spree_variants.id")
        .where("o_inventory_items.id IS NULL OR o_inventory_items.visible = (?)", true)
    }

    scope :stockable_by, lambda { |enterprise|
      return where("1=0") if enterprise.blank?

      joins(:product).
        where(spree_products: { id: Spree::Product.stockable_by(enterprise).pluck(:id) })
    }

    # Define sope as class method to allow chaining with other scopes filtering id.
    # In Rails 3, merging two scopes on the same column will consider only the last scope.
    def self.in_distributor(distributor)
      where(id: ExchangeVariant.select(:variant_id).
                joins(:exchange).
                where('exchanges.incoming = ? AND exchanges.receiver_id = ?', false, distributor))
    end

    def self.indexed
      where(nil).index_by(&:id)
    end

    def self.active(currency = nil)
      # "where(id:" is necessary so that the returned relation has no includes
      # The relation without includes will not be readonly and allow updates on it
      where("spree_variants.id in (?)", joins(:prices).
                                          where(deleted_at: nil).
                                          where('spree_prices.currency' =>
                                            currency || Spree::Config[:currency]).
                                          where('spree_prices.amount IS NOT NULL').
                                          select("spree_variants.id"))
    end

    # Allow variant to access associated soft-deleted prices.
    def default_price
      Spree::Price.unscoped { super }
    end

    def price_with_fees(distributor, order_cycle)
      price + fees_for(distributor, order_cycle)
    end

    def fees_for(distributor, order_cycle)
      OpenFoodNetwork::EnterpriseFeeCalculator.new(distributor, order_cycle).fees_for self
    end

    def fees_by_type_for(distributor, order_cycle)
      OpenFoodNetwork::EnterpriseFeeCalculator.new(distributor, order_cycle).fees_by_type_for self
    end

    # returns number of units currently on backorder for this variant.
    def on_backorder
      inventory_units.with_state('backordered').size
    end

    def gross_profit
      cost_price.nil? ? 0 : (price - cost_price)
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      deleted_at
    end

    def set_option_value(opt_name, opt_value)
      # no option values on master
      return if is_master

      option_type = Spree::OptionType.where(name: opt_name).first_or_initialize do |o|
        o.presentation = opt_name
        o.save!
      end

      current_value = option_values.detect { |o| o.option_type.name == opt_name }

      if current_value.nil?
        # then we have to check to make sure that the product has the option type
        unless product.option_types.include? option_type
          product.option_types << option_type
          product.save
        end
      else
        return if current_value.name == opt_value

        option_values.delete(current_value)
      end

      option_value = Spree::OptionValue.where(option_type_id: option_type.id,
                                              name: opt_value).first_or_initialize do |o|
        o.presentation = opt_value
        o.save!
      end

      option_values << option_value
      save
    end

    def option_value(opt_name)
      option_values.detect { |o| o.option_type.name == opt_name }.try(:presentation)
    end

    def default_price?
      !default_price.nil?
    end

    def price_in(currency)
      prices.select{ |price| price.currency == currency }.first ||
        Spree::Price.new(variant_id: id, currency: currency)
    end

    def amount_in(currency)
      price_in(currency).try(:amount)
    end

    def name_and_sku
      "#{name} - #{sku}"
    end

    # Product may be created with deleted_at already set,
    # which would make AR's default finder return nil.
    # This is a stopgap for that little problem.
    def product
      Spree::Product.unscoped { super }
    end

    # can_supply? is implemented in VariantStock
    def in_stock?(quantity = 1)
      can_supply?(quantity)
    end

    def total_on_hand
      Spree::Stock::Quantifier.new(self).total_on_hand
    end

    private

    # Ensures a new variant takes the product master price when price is not supplied
    def check_price
      if price.nil? && Spree::Config[:require_master_price]
        raise 'No master variant found to infer price' unless product&.master
        raise 'Must supply price for variant or master.price for product.' if self == product.master

        self.price = product.master.price
      end

      return unless currency.nil?

      self.currency = Spree::Config[:currency]
    end

    def save_default_price
      default_price.save if default_price && (default_price.changed? || default_price.new_record?)
    end

    def set_cost_currency
      self.cost_currency = Spree::Config[:currency] if cost_currency.blank?
    end

    def create_stock_items
      StockLocation.all.find_each do |stock_location|
        stock_location.propagate_variant(self)
      end
    end

    def set_position
      update_column(:position, product.variants.maximum(:position).to_i + 1)
    end

    def update_weight_from_unit_value
      return unless product.variant_unit == 'weight' && unit_value.present?

      self.weight = weight_from_unit_value
    end

    def destruction
      exchange_variants(:reload).destroy_all
      yield
    end

    def ensure_unit_value
      return unless product&.variant_unit == "items" && unit_value.nil?

      self.unit_value = 1.0
    end
  end
end
