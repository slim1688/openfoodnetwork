# frozen_string_literal: true

# Serializer used to render the DFC Person from an OFN User
# into JSON-LD format based on DFC ontology
module DfcProvider
  class PersonSerializer < ActiveModel::Serializer
    attribute :context, key: '@context'
    attribute :id, key: '@id'
    attribute :type, key: '@type'
    attribute :family_name, key: 'dfc:familyName'
    attribute :first_name, key: 'dfc:firstName'
    has_one :address,
            key: 'dfc:hasAddress',
            serializer: DfcProvider::AddressSerializer
    has_many :affiliates,
             key: 'dfc:affiliates',
             serializer: DfcProvider::EnterpriseSerializer

    # Context should be provided inside the controller,
    # but AMS doesn't not supported `meta` and `meta_key` with `root` to nil...
    def context
      {
        'dfc' => 'http://datafoodconsortium.org/ontologies/DFC_FullModel.owl#',
        '@base' => "#{root_url}api/dfc_provider"
      }
    end

    def id
      dfc_provider_routes.api_dfc_provider_person_url(
        id: object.id,
        host: root_url
      )
    end

    def type
      'dfc:Person'
    end

    def family_name; end

    def first_name; end

    def address; end

    def affiliates
      object.enterprises
    end

    private

    def dfc_provider_routes
      DfcProvider::Engine.routes.url_helpers
    end
  end
end
