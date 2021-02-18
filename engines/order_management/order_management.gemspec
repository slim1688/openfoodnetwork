# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require "order_management/version"

Gem::Specification.new do |s|
  s.name        = "order_management"
  s.version     = OrderManagement::VERSION
  s.authors     = ["developers@ofn"]
  s.summary     = "Order Management domain of the OFN solution."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["LICENSE.txt", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]
end
