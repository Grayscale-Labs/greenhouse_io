# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GreenhouseIo::V3::PartnerClient do
  let(:token_store) do
    {
      access_token: "test_bearer_token",
      expires_at: (Time.now + 3600).iso8601
    }
  end

  let(:client) do
    described_class.new(
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      token_store: token_store
    )
  end

  let(:jobs_response_body) do
    [{ "id" => 1, "name" => "Software Engineer" }, { "id" => 2, "name" => "Designer" }]
  end

  let(:default_response_headers) do
    {
      "Content-Type" => "application/json",
      "x-ratelimit-limit" => "50",
      "x-ratelimit-remaining" => "49",
      "link" => ""
    }
  end

  before do
    stub_request(:get, /harvest\.greenhouse\.io\/v3/)
      .with(headers: { "Authorization" => "Bearer test_bearer_token" })
      .to_return(
        status: 200,
        body: JSON.dump(jobs_response_body),
        headers: default_response_headers
      )
  end

  describe "#initialize" do
    it "does not require a sub argument" do
      expect(described_class.instance_method(:initialize).parameters).not_to include([:keyreq, :sub])
    end
  end

  describe "#jobs" do
    it "delegates to BaseClient and returns a JobCollection" do
      result = client.jobs
      expect(result).to be_a(GreenhouseIo::JobCollection)
    end
  end

  describe "#get_from_harvest_api" do
    context "successful request" do
      it "makes a GET with Bearer auth" do
        result = client.get_from_harvest_api("/jobs", { per_page: 2 })
        expect(result).to be_an(Array)
        expect(result.first["id"]).to eq(1)
      end
    end

    context "when token is expired (401)" do
      let(:token_response) do
        {
          "access_token" => "refreshed_token",
          "refresh_token" => "rotated_refresh",
          "expires_at" => (Time.now + 3600).iso8601
        }
      end

      before do
        token_store[:refresh_token] = "stored_refresh_token"

        stub_request(:get, /harvest\.greenhouse\.io\/v3/)
          .with(headers: { "Authorization" => "Bearer expired_token" })
          .to_return(status: 401, body: '{"message":"Unauthorized"}', headers: default_response_headers)

        stub_request(:post, "https://auth.greenhouse.io/token")
          .to_return(status: 200, body: JSON.dump(token_response), headers: { "Content-Type" => "application/json" })

        stub_request(:get, /harvest\.greenhouse\.io\/v3/)
          .with(headers: { "Authorization" => "Bearer refreshed_token" })
          .to_return(status: 200, body: JSON.dump(jobs_response_body), headers: default_response_headers)
      end

      it "refreshes and retries" do
        token_store[:access_token] = "expired_token"
        token_store[:expires_at] = (Time.now + 3600).iso8601

        result = client.get_from_harvest_api("/jobs", { per_page: 2 })
        expect(result).to be_an(Array)
        expect(token_store[:access_token]).to eq("refreshed_token")
      end
    end

    context "when token is expired (401) and refresh fails" do
      before do
        token_store[:access_token] = "expired_token"
        token_store[:expires_at] = (Time.now + 3600).iso8601
        token_store[:refresh_token] = "bad_refresh_token"

        stub_request(:get, /harvest\.greenhouse\.io\/v3/)
          .with(headers: { "Authorization" => "Bearer expired_token" })
          .to_return(status: 401, body: '{"message":"Unauthorized"}', headers: default_response_headers)

        stub_request(:post, "https://auth.greenhouse.io/token")
          .to_return(status: 400, body: '{"error":"invalid_grant"}')
      end

      it "raises ReauthorizationRequired" do
        expect do
          client.get_from_harvest_api("/jobs", { per_page: 2 })
        end.to raise_error(GreenhouseIo::ReauthorizationRequired)
      end
    end
  end
end
