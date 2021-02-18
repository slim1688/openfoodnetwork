# Representation of an enterprise being part of an order cycle.
#
# A producer can be part as supplier. The supplier's products can be selected to
# be available in the order cycle (incoming products).
#
# A selling enterprise can be part as distributor. The order cycle then appears
# in its shopfront. Any incoming product can be selected to be shown in the
# shopfront (outgoing products). But the set of shown products can be smaller
# than all incoming products.
class Exchange < ActiveRecord::Base
  acts_as_taggable

  belongs_to :order_cycle
  belongs_to :sender, class_name: 'Enterprise'
  belongs_to :receiver, class_name: 'Enterprise', touch: true

  has_many :exchange_variants, dependent: :destroy
  has_many :variants, through: :exchange_variants

  has_many :exchange_fees, dependent: :destroy
  has_many :enterprise_fees, through: :exchange_fees

  validates :order_cycle, :sender, :receiver, presence: true
  validates :sender_id, uniqueness: { scope: [:order_cycle_id, :receiver_id, :incoming] }

  accepts_nested_attributes_for :variants

  scope :in_order_cycle, lambda { |order_cycle| where(order_cycle_id: order_cycle) }
  scope :incoming, -> { where(incoming: true) }
  scope :outgoing, -> { where(incoming: false) }
  scope :from_enterprise, lambda { |enterprise| where(sender_id: enterprise) }
  scope :to_enterprise, lambda { |enterprise| where(receiver_id: enterprise) }
  scope :from_enterprises, lambda { |enterprises| where('exchanges.sender_id IN (?)', enterprises) }
  scope :to_enterprises, lambda { |enterprises| where('exchanges.receiver_id IN (?)', enterprises) }
  scope :involving, lambda { |enterprises|
    where('exchanges.receiver_id IN (?) OR exchanges.sender_id IN (?)', enterprises, enterprises).
      select('DISTINCT exchanges.*')
  }
  scope :supplying_to, lambda { |distributor|
    where('exchanges.incoming OR exchanges.receiver_id = ?', distributor)
  }
  scope :with_variant, lambda { |variant|
    joins(:exchange_variants).where('exchange_variants.variant_id = ?', variant)
  }
  scope :with_any_variant, lambda { |variant_ids|
    joins(:exchange_variants).
      where(exchange_variants: { variant_id: variant_ids }).
      select('DISTINCT exchanges.*')
  }
  scope :with_product, lambda { |product|
    joins(:exchange_variants).
      where('exchange_variants.variant_id IN (?)', product.variants_including_master.select(&:id))
  }
  scope :by_enterprise_name, -> {
    joins('INNER JOIN enterprises AS sender   ON (sender.id   = exchanges.sender_id)').
      joins('INNER JOIN enterprises AS receiver ON (receiver.id = exchanges.receiver_id)').
      order("CASE WHEN exchanges.incoming='t' THEN sender.name ELSE receiver.name END")
  }

  # Exchanges on order cycles that are dated and are upcoming or open are cached
  scope :cachable, -> {
    outgoing.
      joins(:order_cycle).
      merge(OrderCycle.dated).
      merge(OrderCycle.not_closed)
  }

  scope :managed_by, lambda { |user|
    if user.has_spree_role?('admin')
      where(nil)
    else
      joins("LEFT JOIN enterprises senders ON senders.id = exchanges.sender_id").
        joins("LEFT JOIN enterprises receivers ON receivers.id = exchanges.receiver_id").
        joins("LEFT JOIN enterprise_roles sender_roles ON sender_roles.enterprise_id = senders.id").
        joins("LEFT JOIN enterprise_roles receiver_roles
            ON receiver_roles.enterprise_id = receivers.id").
        where("sender_roles.user_id = ? AND receiver_roles.user_id = ?", user.id, user.id)
    end
  }

  def clone!(new_order_cycle)
    exchange = dup
    exchange.order_cycle = new_order_cycle
    exchange.enterprise_fee_ids = enterprise_fee_ids
    exchange.variant_ids = variant_ids
    exchange.tag_ids = tag_ids
    exchange.save!
    exchange
  end

  def role
    incoming? ? 'supplier' : 'distributor'
  end

  def participant
    incoming? ? sender : receiver
  end
end
