# frozen_string_literal: true

module Api
  module Admin
    class OrderSerializer < ActiveModel::Serializer
      attributes :id, :number, :user_id, :full_name, :email, :phone, :completed_at, :display_total,
                 :edit_path, :state, :payment_state, :shipment_state,
                 :payments_path, :ready_to_ship, :ready_to_capture, :created_at,
                 :distributor_name, :special_instructions, :display_outstanding_balance,
                 :item_total, :adjustment_total, :payment_total, :total

      has_one :distributor, serializer: Api::Admin::IdSerializer
      has_one :order_cycle, serializer: Api::Admin::IdSerializer

      def full_name
        object.billing_address.nil? ? "" : ( object.billing_address.full_name || "" )
      end

      def distributor_name
        object.distributor.andand.name
      end

      def display_outstanding_balance
        return "" if object.outstanding_balance.zero?

        object.display_outstanding_balance.to_s
      end

      def edit_path
        return '' unless object.id

        spree_routes_helper.edit_admin_order_path(object)
      end

      def payments_path
        return '' unless object.payment_state

        spree_routes_helper.admin_order_payments_path(object)
      end

      def ready_to_capture
        pending_payment = object.pending_payments.first
        object.payment_required? && pending_payment
      end

      def ready_to_ship
        object.ready_to_ship?
      end

      def display_total
        object.display_total.to_html
      end

      def email
        object.email || ""
      end

      def phone
        object.billing_address.nil? ? "a" : ( object.billing_address.phone || "" )
      end

      def created_at
        object.created_at.blank? ? "" : I18n.l(object.created_at, format: '%B %d, %Y')
      end

      def completed_at
        object.completed_at.blank? ? "" : I18n.l(object.completed_at, format: '%B %d, %Y')
      end

      private

      def spree_routes_helper
        Spree::Core::Engine.routes.url_helpers
      end
    end
  end
end
