class InventoryItem < ActiveRecord::Base
  belongs_to :enterprise
  belongs_to :variant, class_name: "Spree::Variant"

  validates :variant_id, uniqueness: { scope: :enterprise_id }
  validates :enterprise_id, presence: true
  validates :variant_id, presence: true
  validates :visible, inclusion: { in: [true, false], message: I18n.t(:inventory_item_visibility_error) }

  scope :visible, -> { where(visible: true) }
  scope :hidden, -> { where(visible: false) }
end
