# frozen_string_literal: true

source 'https://rubygems.org'
ruby "2.4.4"
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

plugin 'bootboot', '~> 0.1.1' unless Bundler.settings[:frozen]
Plugin.__send__(:load_plugin, 'bootboot') if Plugin.installed?('bootboot')

if ENV['DEPENDENCIES_NEXT']
  enable_dual_booting if Plugin.installed?('bootboot')

  # This will only be loaded when running
  # bundler command prefixed with `DEPENDENCIES_NEXT=1
  gem 'rails', '> 5.0', '< 5.1'

  gem 'activemerchant', '>= 1.78.0'
  gem 'angular-rails-templates', '>= 0.3.0', '< 1.1.0'
  gem 'awesome_nested_set'
  gem 'rails-controller-testing'
  gem 'ransack', '2.3.0'
  gem 'responders'
else
  gem 'rails', '~> 4.2'

  gem 'activemerchant', '~> 1.78.0'
  gem 'angular-rails-templates', '~> 0.3.0'
  gem 'awesome_nested_set', '~> 3.3.1'
  gem 'ransack', '~> 1.8.10'
  gem 'responders', '~> 2.0'

  gem 'db2fog'
  gem 'unicorn'

  group :test do
    gem 'test_after_commit' # needed to test Devise callbacks
  end
end

gem 'i18n'
gem 'i18n-js', '~> 3.8.0'
gem 'rails-i18n'
gem 'rails_safe_tasks', '~> 1.0'

gem "activerecord-import"

gem "catalog", path: "./engines/catalog"
gem 'dfc_provider', path: './engines/dfc_provider'
gem "order_management", path: "./engines/order_management"
gem 'web', path: './engines/web'

gem 'activerecord-postgresql-adapter'
gem 'pg', '~> 0.21.0'

gem 'acts_as_list', '0.9.19'
gem 'cancancan', '~> 1.7.0'
gem 'ffaker'
gem 'highline', '2.0.3' # Necessary for the install generator
gem 'json'
gem 'monetize', '~> 1.10'
gem 'paranoia', '~> 2.4'
gem 'state_machines-activerecord'
gem 'stringex', '~> 2.8.5'

gem 'paypal-sdk-merchant', '1.117.2'
gem 'stripe'

gem 'devise'
gem 'devise-encryptable'
gem 'devise-token_authenticatable'
gem 'jwt', '~> 2.2'
gem 'oauth2', '~> 1.4.4' # Used for Stripe Connect

gem 'daemons'
gem 'delayed_job_active_record'
gem 'delayed_job_web'

gem 'kaminari', '~> 1.2.1'

gem 'andand'
gem 'angularjs-rails', '1.5.5'
gem 'aws-sdk', '1.67.0'
gem 'bugsnag'
gem 'haml'
gem 'redcarpet'

gem 'actionpack-action_caching'
# AMS 0.9.x and 0.10.x are very different from 0.8.4 and the upgrade is not straight forward
#   AMS is deprecated, we will introduce an alternative at some point
gem "active_model_serializers", "0.8.4"
gem 'activerecord-session_store'
gem 'acts-as-taggable-on', '~> 4.0'
gem 'angularjs-file-upload-rails', '~> 2.4.1'
gem 'custom_error_message', github: 'jeremydurham/custom-err-msg'
gem 'dalli'
gem 'figaro'
gem 'geocoder'
gem 'gmaps4rails'
gem 'paper_trail', '~> 10.3.1'
gem 'paperclip', '~> 3.4.1'
gem 'rack-rewrite'
gem 'rack-ssl', require: 'rack/ssl'
gem 'roadie-rails', '~> 1.3.0'

gem 'combine_pdf'
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'

gem 'immigrant'
gem 'roo', '~> 2.8.3'

gem 'whenever', require: false

gem 'test-unit', '~> 3.4'

gem 'coffee-rails', '~> 4.2.2'
gem 'compass-rails'

gem 'libv8', '< 8'
gem 'mini_racer', '0.2.15'

gem 'uglifier', '>= 1.0.3'

gem 'angular_rails_csrf'
gem 'foundation-icons-sass-rails'
gem 'sass', '<= 4.7.1'
gem 'sass-rails', '< 6.0.0'

gem 'foundation-rails', '= 5.5.2.1'

gem 'jquery-migrate-rails'
gem 'jquery-rails', '4.4.0'
gem 'jquery-ui-rails', '~> 4.2'
gem 'select2-rails', '~> 3.4.7'

gem 'ofn-qz', github: 'openfoodfoundation/ofn-qz', branch: 'ofn-rails-4'

group :production, :staging do
  gem 'ddtrace'
  gem 'unicorn-worker-killer'
end

group :test, :development do
  # Pretty printed test output
  gem 'atomic'
  gem 'awesome_print'
  gem 'capybara'
  gem 'database_cleaner', require: false
  gem "factory_bot_rails", '5.2.0', require: false
  gem 'fuubar', '~> 2.5.1'
  gem 'json_spec', '~> 1.1.4'
  gem 'knapsack'
  gem 'letter_opener', '>= 1.4.1'
  gem 'rspec-rails', ">= 3.5.2"
  gem 'rspec-retry'
  gem 'rswag'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
  gem 'timecop'
  gem 'unicorn-rails'
  gem 'webdrivers'
end

group :test do
  gem 'simplecov', require: false
  gem 'test-prof'
  gem 'webmock'
  # See spec/spec_helper.rb for instructions
  # gem 'perftools.rb'
end

group :development do
  gem 'byebug'
  gem 'debugger-linecache'
  gem 'pry'
  gem 'pry-byebug'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'spring'
  gem 'spring-commands-rspec'

  # 1.0.9 fixed openssl issues on macOS https://github.com/eventmachine/eventmachine/issues/602
  # While we don't require this gem directly, no dependents forced the upgrade to a version
  # greater than 1.0.9, so we just required the latest available version here.
  gem 'eventmachine', '>= 1.2.3'

  gem 'rack-mini-profiler', '< 3.0.0'
end
