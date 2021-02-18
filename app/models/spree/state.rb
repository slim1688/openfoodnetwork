# frozen_string_literal: true

module Spree
  class State < ActiveRecord::Base
    belongs_to :country, class_name: 'Spree::Country'

    validates :country, :name, presence: true

    def self.find_all_by_name_or_abbr(name_or_abbr)
      where('name = ? OR abbr = ?', name_or_abbr, name_or_abbr)
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
