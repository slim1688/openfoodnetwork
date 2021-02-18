# frozen_string_literal: true

# Serializer used to render a DFC CatalogItem from an OFN Product
# into JSON-LD format based on DFC ontology
module DfcProvider
  class CatalogItemSerializer < ActiveModel::Serializer
    attribute :id, key: '@id'
    attribute :type, key: '@type'
    attribute :references, key: 'dfc:references'
    attribute :sku, key: 'dfc:sku'
    attribute :stock_limitation, key: 'dfc:stockLimitation'
    has_many :offered_through,
             serializer: DfcProvider::OfferSerializer,
             key: 'dfc:offeredThrough'

    def id
      dfc_provider_routes.api_dfc_provider_enterprise_catalog_item_url(
        enterprise_id: object.product.supplier_id,
        id: object.id,
        host: root_url
      )
    end

    def type
      'dfc:CatalogItem'
    end

    def references
      {
        '@type' => '@id',
        '@id' => "/supplied_products/#{object.product_id}"
      }
    end

    def stock_limitation; end

    def offered_through
      [object]
    end

    private

    def reference_id
      dfc_provider_routes.api_dfc_provider_enterprise_supplied_product_url(
        enterprise_id: object.product.supplier_id,
        id: object.product_id,
        host: root_url
      )
    end

    def dfc_provider_routes
      DfcProvider::Engine.routes.url_helpers
    end
  end
end
