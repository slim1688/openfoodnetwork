# frozen_string_literal: true

module Api
  module Admin
    class VariantSerializer < ActiveModel::Serializer
      attributes :id, :name, :producer_name, :image, :sku, :import_date,
                 :options_text, :unit_value, :unit_description, :unit_to_display,
                 :display_as, :display_name, :name_to_display, :variant_overrides_count,
                 :price, :on_demand, :on_hand, :in_stock, :stock_location_id, :stock_location_name

      def name
        if object.full_name.present?
          "#{object.name} - #{object.full_name}"
        else
          object.name
        end
      end

      def on_hand
        return 0 if object.on_hand.nil?

        object.on_hand
      end

      def price
        # Decimals are passed to json as strings,
        #   we need to run parseFloat.toFixed(2) on the client.
        object.price.nil? ? 0.to_f : object.price
      end

      def producer_name
        object.product.supplier.name
      end

      def image
        return if object.product.images.empty?

        object.product.images.first.mini_url
      end

      def in_stock
        object.in_stock?
      end

      def stock_location_id
        return if object.stock_items.empty?

        object.stock_items.first.stock_location.id
      end

      def stock_location_name
        return if object.stock_items.empty?

        object.stock_items.first.stock_location.name
      end

      def variant_overrides_count
        object.variant_overrides.count
      end
    end
  end
end
