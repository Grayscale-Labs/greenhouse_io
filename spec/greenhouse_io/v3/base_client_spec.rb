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

  describe "rate limit budget" do
    let(:budget_headers) do
      { "X-RateLimit-Limit" => "75", "X-RateLimit-Remaining" => "3", "X-RateLimit-Reset" => "1756285800" }
    end

    let(:reported) { [] }

    let(:callback_client) do
      GreenhouseIo::V3::PartnerClient.new(
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        token_store: token_store,
        on_rate_limit_budget: ->(limit:, remaining:, reset_at:) { reported << [limit, remaining, reset_at] }
      )
    end

    it "records when the current window resets" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 200, body: "[]", headers: budget_headers)

      client.get_from_harvest_api("/jobs")

      expect(client.rate_limit_reset).to eq(1_756_285_800)
    end

    it "populates the accessors when no callback was given" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 200, body: "[]", headers: budget_headers)

      client.get_from_harvest_api("/jobs")

      expect(client.rate_limit).to eq(75)
      expect(client.rate_limit_remaining).to eq(3)
    end

    it "reports the budget to the consumer callback" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 200, body: "[]", headers: budget_headers)

      callback_client.get_from_harvest_api("/jobs")

      expect(reported).to eq([[75, 3, 1_756_285_800]])
    end

    it "reports the budget on a rejected response as well" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 429, body: "Retry later",
                   headers: budget_headers.merge("X-RateLimit-Remaining" => "0"))

      expect { callback_client.get_from_harvest_api("/jobs") }.to raise_error(GreenhouseIo::Error)

      expect(reported).to eq([[75, 0, 1_756_285_800]])
    end

    it "stays quiet when the response carries no rate limit headers" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs").to_return(status: 502, body: "")

      expect { callback_client.get_from_harvest_api("/jobs") }.to raise_error(GreenhouseIo::Error)

      # Zeroed accessors would otherwise read as an exhausted budget on any header-less response.
      expect(reported).to be_empty
    end

    it "stays quiet when a budget header is present but empty" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 200, body: "[]", headers: { "X-RateLimit-Remaining" => "" })

      callback_client.get_from_harvest_api("/jobs")

      expect(reported).to be_empty
    end

    it "stays quiet on a partial budget rather than report the missing keys as zero" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 200, body: "[]", headers: { "X-RateLimit-Remaining" => "40" })

      callback_client.get_from_harvest_api("/jobs")

      expect(reported).to be_empty
    end

    it "reports once per response across the refresh-and-retry path" do
      token_store[:refresh_token] = "stored_refresh"

      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .with(headers: { "Authorization" => "Bearer test_bearer_token" })
        .to_return(status: 401, body: '{"message":"Unauthorized"}', headers: budget_headers)

      stub_request(:post, "https://auth.greenhouse.io/token")
        .to_return(
          status: 200,
          body: JSON.dump("access_token" => "refreshed_token", "refresh_token" => "rotated",
                          "expires_at" => (Time.now + 3600).iso8601),
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .with(headers: { "Authorization" => "Bearer refreshed_token" })
        .to_return(status: 200, body: "[]", headers: budget_headers.merge("X-RateLimit-Remaining" => "2"))

      callback_client.get_from_harvest_api("/jobs")

      expect(reported).to eq([[75, 3, 1_756_285_800], [75, 2, 1_756_285_800]])
    end

    it "does not fail an accepted request when the callback raises" do
      raising_client = GreenhouseIo::V3::PartnerClient.new(
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        token_store: token_store,
        on_rate_limit_budget: ->(**_budget) { raise "consumer bug" }
      )
      stub_request(:post, "https://harvest.greenhouse.io/v3/webhooks")
        .to_return(status: 201, body: JSON.dump("id" => 1), headers: budget_headers)

      result = nil
      expect { result = raising_client.post_to_harvest_api("/webhooks", {}) }
        .to output(/consumer bug/).to_stderr

      expect(result["id"]).to eq(1)
    end

    it "is forwarded by the custom-integration client too" do
      custom_client = GreenhouseIo::V3::CustomClient.new(
        client_id: "id",
        client_secret: "secret",
        sub: "1",
        token_store: { access_token: "custom_token", expires_at: (Time.now + 3600).iso8601 },
        on_rate_limit_budget: ->(limit:, remaining:, reset_at:) { reported << [limit, remaining, reset_at] }
      )
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 200, body: "[]", headers: budget_headers)

      custom_client.get_from_harvest_api("/jobs")

      expect(reported).to eq([[75, 3, 1_756_285_800]])
    end
  end

  describe "throttled Harvest requests" do
    it "carries the throttle headers on a 429" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs")
        .to_return(status: 429, body: "Retry later",
                   headers: { "Retry-After" => "12", "X-RateLimit-Remaining" => "0" })

      expect { client.get_from_harvest_api("/jobs") }.to raise_error(GreenhouseIo::Error) { |e|
        # Harvest states the status in the message and leaves code unset, unlike the token endpoint.
        expect(e.message).to eq("429")
        expect(e.code).to be_nil
        expect(e.headers["retry-after"]).to eq("12")
      }
    end

    it "carries them on a throttled write too" do
      stub_request(:post, "https://harvest.greenhouse.io/v3/webhooks")
        .to_return(status: 429, body: "Retry later", headers: { "Retry-After" => "9" })

      expect { client.post_to_harvest_api("/webhooks", {}) }.to raise_error(GreenhouseIo::Error) { |e|
        expect(e.headers["retry-after"]).to eq("9")
      }
    end

    it "reports an empty hash rather than nil when a failure carries no headers" do
      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs").to_return(status: 500, body: "")

      expect { client.get_from_harvest_api("/jobs") }.to raise_error(GreenhouseIo::Error) { |e|
        expect(e.headers).to eq({})
      }
    end
  end
end
