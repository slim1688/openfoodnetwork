# frozen_string_literal: true

# This controller lists products that can be added to an exchange
#
# Pagination is optional and can be required by using param[:page]
module Api
  class ExchangeProductsController < Api::BaseController
    include PaginationData
    DEFAULT_PER_PAGE = 100

    skip_authorization_check only: [:index]

    # If exchange_id is present in the URL:
    #   Lists Products that can be added to that Exchange
    #
    # If exchange_id is not present in the URL:
    #   Lists Products of the Enterprise given that can be added to the given Order Cycle
    #   In this case parameters are: enterprise_id, order_cycle_id and incoming
    #     (order_cycle_id is not necessary for incoming exchanges)
    def index
      if params[:exchange_id].present?
        load_data_from_exchange
      else
        load_data_from_other_params
      end

      render_variant_count && return if params[:action_name] == "variant_count"

      render_paginated_products paginated_products
    end

    private

    def render_variant_count
      render text: {
        count: variants.count
      }.to_json
    end

    def variants
      renderer.exchange_variants(@incoming, @enterprise)
    end

    def products
      renderer.exchange_products(@incoming, @enterprise)
    end

    def renderer
      @renderer ||= ExchangeProductsRenderer.
        new(@order_cycle, spree_current_user)
    end

    def paginated_products
      return products unless pagination_required?

      products.
        page(params[:page]).
        per(params[:per_page] || DEFAULT_PER_PAGE)
    end

    def load_data_from_exchange
      exchange = Exchange.find_by(id: params[:exchange_id])

      @order_cycle = exchange.order_cycle
      @incoming = exchange.incoming
      @enterprise = exchange.sender
    end

    def load_data_from_other_params
      @enterprise = Enterprise.find_by(id: params[:enterprise_id])

      if params[:order_cycle_id]
        @order_cycle = OrderCycle.find_by(id: params[:order_cycle_id])
      elsif !params[:incoming]
        raise "order_cycle_id is required to list products for new outgoing exchange"
      end
      @incoming = params[:incoming]
    end

    def render_paginated_products(paginated_products)
      serialized_products = ActiveModel::ArraySerializer.new(
        paginated_products,
        each_serializer: Api::Admin::ForOrderCycle::SuppliedProductSerializer,
        order_cycle: @order_cycle
      )

      render json: {
        products: serialized_products,
        pagination: pagination_data(paginated_products)
      }
    end
  end
end
