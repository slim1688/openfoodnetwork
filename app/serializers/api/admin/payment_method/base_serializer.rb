# frozen_string_literal: true

module Api
  module Admin
    module PaymentMethod
      class BaseSerializer < ActiveModel::Serializer
        attributes :id, :name, :type, :tag_list, :tags

        def tag_list
          object.tag_list.join(",")
        end

        def tags
          object.tag_list.map{ |t| { text: t } }
        end
      end
    end
  end
end
