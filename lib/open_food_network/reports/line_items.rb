module OpenFoodNetwork
  module Reports
    # shared code to search and list line items
    class LineItems
      def initialize(order_permissions, params)
        @order_permissions = order_permissions
        @params = params
      end

      def orders
        @orders ||= search_orders
      end

      def list(line_item_includes = nil)
        line_items = @order_permissions.visible_line_items.in_orders(orders.result)

        if @params[:supplier_id_in].present?
          line_items = line_items.supplied_by_any(@params[:supplier_id_in])
        end

        if line_item_includes.present?
          line_items = line_items.includes(*line_item_includes).references(:line_items)
        end

        editable_line_items = editable_line_items(line_items)

        line_items.reject{ |li|
          editable_line_items.include? li
        }.each do |line_item|
          OrderDataMasker.new(line_item.order).call
        end

        line_items
      end

      private

      def search_orders
        @order_permissions.visible_orders.complete.not_state(:canceled).search(@params[:q])
      end

      # From the line_items given, returns the ones that are editable by the user
      def editable_line_items(line_items)
        editable_line_items_ids = @order_permissions.editable_line_items.select(:id)

        # Although merge could take a relation, here we convert line_items to array
        #   because, if we pass a relation, merge will overwrite the conditions on the same field
        #   In this case: the IN clause on spree_line_items.order_id from line_items
        #     overwrites the IN clause on spree_line_items.order_id on editable_line_items_ids
        # We convert to array the relation with less elements: line_items
        editable_line_items_ids.merge(line_items.to_a)
      end
    end
  end
end
