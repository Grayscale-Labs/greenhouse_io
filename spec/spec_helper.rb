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
  config.filter_sensitive_data('<API_TOKEN>')  { ENV['GREENHOUSE_API_TOKEN'] }
  config.filter_sensitive_data('<AUTH_VALUE>') { Base64.encode64("#{ENV['GREENHOUSE_API_TOKEN']}:").chomp }
  config.filter_sensitive_data('<V3_CLIENT_ID>')     { ENV['GREENHOUSE_V3_CLIENT_ID'] }
  config.filter_sensitive_data('<V3_CLIENT_SECRET>') { ENV['GREENHOUSE_V3_CLIENT_SECRET'] }
  config.filter_sensitive_data('<V3_BASIC_AUTH>') {
    id = ENV['GREENHOUSE_V3_CLIENT_ID']
    secret = ENV['GREENHOUSE_V3_CLIENT_SECRET']
    Base64.strict_encode64("#{id}:#{secret}") if id && secret
  }
  config.filter_sensitive_data('<V3_ACCESS_TOKEN>') do |interaction|
    interaction.response.body[/"access_token":"([^"]+)"/, 1]
  end
  config.filter_sensitive_data('Bearer <V3_BEARER_TOKEN>') do |interaction|
    auth = interaction.request.headers['Authorization']&.first
    auth if auth&.start_with?('Bearer ')
  end
  config.default_cassette_options = { record: ENV.fetch('VCR_RECORD_MODE', 'once').to_sym }
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.filter_run_when_matching :focus
end

def restore_default_config
  GreenhouseIo.configuration = nil
  GreenhouseIo.configure {}
end
