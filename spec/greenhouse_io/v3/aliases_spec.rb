# frozen_string_literal: true

require 'spec_helper'

# These aliases preserve the pre-rename names for existing consumers. The
# assertions guard against a future rename of the Custom* classes silently
# orphaning the alias and breaking consumers still calling V3::Client /
# V3::TokenManager.
RSpec.describe "GreenhouseIo::V3 backward-compatible aliases" do
  it "aliases V3::Client to V3::CustomClient" do
    expect(GreenhouseIo::V3::Client).to equal(GreenhouseIo::V3::CustomClient)
  end

  it "aliases V3::TokenManager to V3::CustomTokenManager" do
    expect(GreenhouseIo::V3::TokenManager).to equal(GreenhouseIo::V3::CustomTokenManager)
  end
end
