class EnterpriseFee < ActiveRecord::Base
  include Spree::Core::CalculatedAdjustments

  acts_as_paranoid

  belongs_to :enterprise
  belongs_to :tax_category, class_name: 'Spree::TaxCategory', foreign_key: 'tax_category_id'

  has_many :coordinator_fees, dependent: :destroy
  has_many :order_cycles, through: :coordinator_fees

  has_many :exchange_fees, dependent: :destroy
  has_many :exchanges, through: :exchange_fees

  FEE_TYPES = %w(packing transport admin sales fundraising).freeze
  PER_ORDER_CALCULATORS = ['Calculator::FlatRate',
                           'Calculator::FlexiRate',
                           'Calculator::PriceSack'].freeze

  validates :fee_type, inclusion: { in: FEE_TYPES }
  validates :name, presence: true

  before_save :ensure_valid_tax_category_settings

  scope :for_enterprise, lambda { |enterprise| where(enterprise_id: enterprise) }
  scope :for_enterprises, lambda { |enterprises| where(enterprise_id: enterprises) }

  scope :managed_by, lambda { |user|
    if user.has_spree_role?('admin')
      where(nil)
    else
      where('enterprise_id IN (?)', user.enterprises.select(&:id))
    end
  }

  scope :per_item, lambda {
    joins(:calculator).where('spree_calculators.type NOT IN (?)', PER_ORDER_CALCULATORS)
  }
  scope :per_order, lambda {
    joins(:calculator).where('spree_calculators.type IN (?)', PER_ORDER_CALCULATORS)
  }

  def self.clear_all_adjustments_on_order(order)
    order.adjustments.where(originator_type: 'EnterpriseFee').destroy_all
  end

  private

  def ensure_valid_tax_category_settings
    # Setting an explicit tax_category removes any inheritance behaviour
    # In the absence of any current changes to tax_category, setting
    # inherits_tax_category to true will clear the tax_category
    if tax_category_id_changed?
      self.inherits_tax_category = false if tax_category.present?
    elsif inherits_tax_category_changed?
      self.tax_category_id = nil if inherits_tax_category?
    end
    true
  end
end
