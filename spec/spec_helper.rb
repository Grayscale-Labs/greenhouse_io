require 'simplecov'
SimpleCov.start

require 'rubygems'
require 'bundler'
require 'webmock/rspec'
require 'vcr'
require 'greenhouse_io'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/cassettes'
  config.hook_into :webmock
  config.ignore_hosts 'codeclimate.com'
  config.filter_sensitive_data('<API_TOKEN>') { ENV['API_TOKEN'] }
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.filter_run_when_matching :focus
end

def restore_default_config
  GreenhouseIo.configuration = nil
  GreenhouseIo.configure {}
end
