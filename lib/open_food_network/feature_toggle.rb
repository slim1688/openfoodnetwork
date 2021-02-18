module OpenFoodNetwork
  # This feature toggles implementation provides two mechanisms to conditionally enable features.
  #
  # You can provide an ENV var with the prefix `OFN_FEATURE_` and query it using the
  # `ApplicationHelper#feature?` helper method. For instance, providing the ENV var
  # `OFN_FEATURE_NEW_SHINNY_FEATURE` you could then query it from view as follows:
  #
  #   - if feature? :new_shiny_feature
  #     = render "new_shiny_feature"
  #
  # Alternatively, you can choose which users have the feature toggled on. To do that you need to
  # register the feature and its users from an initializer like:
  #
  #   require 'open_food_network/feature_toggle'
  #   OpenFoodNetwork::FeatureToggle.enable(:new_shiny_feature, ['ofn@example.com'])
  #
  # Note, however, that it'd be better to read the user emails from an ENV var provisioned with
  # ofn-install:
  #
  #   require 'open_food_network/feature_toggle'
  #   OpenFoodNetwork::FeatureToggle.enable(:new_shiny_feature, ENV['PRODUCT_TEAM'])
  #
  # You can then check it from a view like:
  #
  #   - if feature? :new_shiny_feature, spree_current_user
  #     = render "new_shiny_feature"
  #
  class FeatureToggle
    def self.enabled?(feature_name, user = nil)
      new.enabled?(feature_name, user)
    end

    def self.enable(feature_name, &block)
      Thread.current[:features] ||= {}
      Thread.current[:features][feature_name] = Feature.new(block)
    end

    def initialize
      @features = Thread.current[:features] || {}
    end

    def enabled?(feature_name, user)
      if user.present?
        feature = features.fetch(feature_name, NullFeature.new)
        feature.enabled?(user)
      else
        true?(env_variable_value(feature_name))
      end
    end

    private

    attr_reader :features

    def env_variable_value(feature_name)
      ENV.fetch(env_variable_name(feature_name), nil)
    end

    def env_variable_name(feature_name)
      "OFN_FEATURE_#{feature_name.to_s.upcase}"
    end

    def true?(value)
      value.to_s.casecmp("true").zero?
    end
  end

  class Feature
    def initialize(block)
      @block = block
    end

    def enabled?(user)
      block.call(user)
    end

    private

    attr_reader :block
  end

  class NullFeature
    def enabled?(_user)
      false
    end
  end
end
