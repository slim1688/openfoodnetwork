# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require "dfc_provider/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'dfc_provider'
  spec.version     = DfcProvider::VERSION
  spec.authors     = ["developers@ofn"]
  spec.summary     = 'Provides an API stack implementing DFC semantic ' \
                     'specifications'

  spec.files = Dir["{app,config,lib}/**/*"] + ['README.md']
  spec.test_files = Dir['spec/**/*']

  spec.add_dependency 'active_model_serializers', '~> 0.8.4'
  spec.add_dependency 'jwt', '~> 2.2'
  spec.add_dependency 'rspec', '~> 3.9'
end
