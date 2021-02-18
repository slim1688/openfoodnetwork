module Api
  class CustomerSerializer < ActiveModel::Serializer
    attributes :id, :enterprise_id, :name, :code, :email, :allow_charges

    def attributes
      hash = super
      if secret = object.gateway_recurring_payment_client_secret
        hash.merge!(gateway_recurring_payment_client_secret: secret)
      end
      hash.merge!(gateway_shop_id: object.gateway_shop_id) if object.gateway_shop_id
      hash
    end
  end
end
