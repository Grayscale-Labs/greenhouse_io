# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'greenhouse_io/version'

Gem::Specification.new do |spec|
  spec.name          = "greenhouse_io"
  spec.version       = GreenhouseIo::VERSION
  spec.authors       = ["Greenhouse Software", "Adrian Bautista"]
  spec.email         = ["support@greenhouse.io", "adrianbautista8@gmail.com"]
  spec.description   = %q{Ruby bindings for the greenhouse.io Harvest API and Job Board API}
  spec.summary       = %q{Ruby bindings for the greenhouse.io Harvest API and Job Board API}
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/grnhse/greenhouse_io"

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency('activesupport')
  spec.add_runtime_dependency('hashie')
  spec.add_runtime_dependency('httmultiparty', '~> 0.3.16')
  spec.add_runtime_dependency('link-header-parser')
  spec.add_runtime_dependency('retriable')
  spec.required_ruby_version = '>= 2.6.6'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "vcr", "~> 6.0.0"
end
