lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ccai/version'

Gem::Specification.new do |spec|
  spec.name          = "ccai"
  spec.version       = CCAI::VERSION
  spec.authors       = ["CloudContactAI"]
  spec.email         = ["info@cloudcontactai.com"]

  spec.summary       = %q{Ruby client for the Cloud Contact AI API}
  spec.description   = %q{A Ruby client for interacting with the Cloud Contact AI API that allows you to easily send SMS and MMS messages.}
  spec.homepage      = "https://github.com/cloudcontactai/ccai-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.files         = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  spec.bindir        = "bin"
  spec.executables   = ["ccai"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "json", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
