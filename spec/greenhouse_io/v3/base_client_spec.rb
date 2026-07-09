# frozen_string_literal: true

require 'spec_helper'

# BaseClient is abstract (subclasses set @token_manager); exercise its shared HTTP behavior
# through PartnerClient with a valid cached token so no auth round-trip happens.
RSpec.describe GreenhouseIo::V3::BaseClient do
  let(:token_store) do
    { access_token: "test_bearer_token", expires_at: (Time.now + 3600).iso8601 }
  end

  let(:client) do
    GreenhouseIo::V3::PartnerClient.new(
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      token_store: token_store
    )
  end

  let(:response_headers) do
    { "Content-Type" => "application/json", "x-ratelimit-limit" => "50", "x-ratelimit-remaining" => "49", "link" => "" }
  end

  describe "#post_to_harvest_api" do
    it "sends Content-Type: application/json" do
      stub = stub_request(:post, "https://harvest.greenhouse.io/v3/webhooks")
             .with(headers: { "Content-Type" => "application/json", "Authorization" => "Bearer test_bearer_token" })
             .to_return(status: 201, body: JSON.dump("id" => 1), headers: response_headers)

      client.post_to_harvest_api("/webhooks", { event_action_type: "hire_candidate" })

      expect(stub).to have_been_requested
    end

    it "lets an explicit header override the default Content-Type" do
      stub = stub_request(:post, "https://harvest.greenhouse.io/v3/webhooks")
             .with(headers: { "Content-Type" => "application/xml" })
             .to_return(status: 201, body: JSON.dump("id" => 1), headers: response_headers)

      client.post_to_harvest_api("/webhooks", {}, { "Content-Type" => "application/xml" })

      expect(stub).to have_been_requested
    end
  end

  describe "#patch_to_harvest_api" do
    it "issues a PATCH with Bearer auth and JSON content type" do
      stub = stub_request(:patch, "https://harvest.greenhouse.io/v3/webhooks/1")
             .with(headers: { "Content-Type" => "application/json", "Authorization" => "Bearer test_bearer_token" })
             .to_return(status: 200, body: JSON.dump("id" => 1, "deactivated" => false), headers: response_headers)

      result = client.patch_to_harvest_api("/webhooks/1", { deactivated: false })

      expect(stub).to have_been_requested
      expect(result["deactivated"]).to be(false)
    end

    it "refreshes the token and retries once on a 401" do
      token_store[:refresh_token] = "stored_refresh"

      stub_request(:patch, "https://harvest.greenhouse.io/v3/webhooks/1")
        .with(headers: { "Authorization" => "Bearer test_bearer_token" })
        .to_return(status: 401, body: '{"message":"Unauthorized"}', headers: response_headers)

      stub_request(:post, "https://auth.greenhouse.io/token")
        .to_return(
          status: 200,
          body: JSON.dump("access_token" => "refreshed_token", "refresh_token" => "rotated",
                          "expires_at" => (Time.now + 3600).iso8601),
          headers: { "Content-Type" => "application/json" }
        )

      retried = stub_request(:patch, "https://harvest.greenhouse.io/v3/webhooks/1")
                .with(headers: { "Authorization" => "Bearer refreshed_token" })
                .to_return(status: 200, body: JSON.dump("id" => 1, "deactivated" => false), headers: response_headers)

      client.patch_to_harvest_api("/webhooks/1", { deactivated: false })

      expect(retried).to have_been_requested
    end
  end
end
