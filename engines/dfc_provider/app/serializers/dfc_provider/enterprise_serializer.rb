# frozen_string_literal: true

# Serializer used to render a DFC Enterprise from an OFN Enterprise
# into JSON-LD format based on DFC ontology
module DfcProvider
  class EnterpriseSerializer < ActiveModel::Serializer
    attribute :id, key: '@id'
    attribute :type, key: '@type'
    attribute :vat_number, key: 'dfc:VATnumber'
    has_many :defines, key: 'dfc:defines'
    has_many :supplies,
             key: 'dfc:supplies',
             serializer: DfcProvider::SuppliedProductSerializer
    has_many :manages,
             key: 'dfc:manages',
             serializer: DfcProvider::CatalogItemSerializer

    def id
      dfc_provider_routes.api_dfc_provider_enterprise_url(
        id: object.id,
        host: root_url
      )
    end

    def type
      'dfc:Entreprise'
    end

    def vat_number; end

    def defines
      []
    end

    def supplies
      Spree::Variant.
        joins(product: :supplier).
        where('enterprises.id' => object.id)
    end

    def manages
      Spree::Variant.
        joins(product: :supplier).
        where('enterprises.id' => object.id)
    end

    private

    def dfc_provider_routes
      DfcProvider::Engine.routes.url_helpers
    end
  end
end
