# frozen_string_literal: true

FactoryBot.define do
  sequence :user_authentication_token do |n|
    "xxxx#{Time.now.to_i}#{rand(1000)}#{n}xxxxxxxxxxxxx"
  end

  factory :user, class: Spree.user_class do
    transient do
      enterprises { [] }
    end

    email { generate(:random_email) }
    login { email }
    password { 'secret' }
    password_confirmation { password }
    authentication_token { generate(:user_authentication_token) } if Spree.user_class.attribute_method? :authentication_token

    confirmation_sent_at { '1970-01-01 00:00:00' }
    confirmed_at { '1970-01-01 00:00:01' }

    before(:create) do |user, evaluator|
      if evaluator.confirmation_sent_at
        if evaluator.confirmed_at
          user.skip_confirmation!
        else
          user.skip_confirmation_notification!
        end
      end
    end

    after(:create) do |user, proxy|
      user.spree_roles.clear # Remove admin role

      user.enterprises << proxy.enterprises
    end

    factory :admin_user do
      spree_roles { [Spree::Role.find_or_create_by!(name: 'admin')] }

      after(:create) do |user|
        user.spree_roles << Spree::Role.find_or_create_by!(name: 'admin')
      end
    end
  end
end
