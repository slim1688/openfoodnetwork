# frozen_string_literal: true

# Serializer used to render the DFC Offer from an OFN Product
# into JSON-LD format based on DFC ontology
module DfcProvider
  class OfferSerializer < ActiveModel::Serializer
    attribute :id, key: '@id'
    attribute :type, key: '@type'
    attribute :offeres_to, key: 'dfc:offeres_to'
    attribute :price, key: 'dfc:price'
    attribute :stock_limitation, key: 'dfc:stockLimitation'

    def id
      "/offers/#{object.id}"
    end

    def type
      'dfc:Offer'
    end

    def offeres_to
      {
        '@type' => '@id',
        '@id' => nil
      }
    end

    def stock_limitation
      object.on_hand
    end
  end
end
