class Api::StateSerializer < ActiveModel::Serializer
  attributes :id, :name, :abbr, :country_id
end
