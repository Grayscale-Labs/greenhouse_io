# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GreenhouseIo::V3::Client do
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
      sub: "12345",
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

  describe "#jobs" do
    it "returns a JobCollection" do
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
          "refresh_token" => "new_refresh",
          "expires_at" => (Time.now + 3600).iso8601
        }
      end

      before do
        stub_request(:get, /harvest\.greenhouse\.io\/v3/)
          .with(headers: { "Authorization" => "Bearer expired_token" })
          .to_return(status: 401, body: '{"message":"Unauthorized"}', headers: default_response_headers)

        stub_request(:post, /auth\.greenhouse\.io\/token/)
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
  end

  describe "#rate_limit" do
    it "tracks rate limit from response headers" do
      client.get_from_harvest_api("/jobs", { per_page: 1 })
      expect(client.rate_limit).to eq(50)
      expect(client.rate_limit_remaining).to eq(49)
    end
  end

  describe "#post_to_harvest_api" do
    before do
      stub_request(:post, /harvest\.greenhouse\.io\/v3/)
        .with(headers: { "Authorization" => "Bearer test_bearer_token" })
        .to_return(status: 200, body: '{"id": 1}', headers: default_response_headers)
    end

    it "makes a POST with Bearer auth" do
      result = client.post_to_harvest_api("/candidates", { first_name: "Test" })
      expect(result).to eq({ "id" => 1 })
    end
  end

  describe "pagination" do
    let(:page1_body) { [{ "id" => 1, "name" => "Engineer" }, { "id" => 2, "name" => "Designer" }] }
    let(:page2_body) { [{ "id" => 3, "name" => "PM" }] }
    let(:next_url) { "https://harvest.greenhouse.io/v3/jobs?cursor=abc123" }

    before do
      WebMock.reset!

      stub_request(:get, "https://harvest.greenhouse.io/v3/jobs?per_page=2")
        .with(headers: { "Authorization" => "Bearer test_bearer_token" })
        .to_return(
          status: 200,
          body: JSON.dump(page1_body),
          headers: default_response_headers.merge("link" => "<#{next_url}>; rel=\"next\"")
        )

      stub_request(:get, next_url)
        .with(headers: { "Authorization" => "Bearer test_bearer_token" })
        .to_return(
          status: 200,
          body: JSON.dump(page2_body),
          headers: default_response_headers
        )
    end

    it "follows next link header across pages" do
      collection = client.jobs(per_page: 2)
      pages = collection.each_page.to_a
      expect(pages.length).to eq(2)
      expect(pages.first).to be_a(GreenhouseIo::ResourceCollection::Page)
    end

    it "iterates all resources lazily" do
      collection = client.jobs(per_page: 2)
      first_job = collection.first
      expect(first_job).to respond_to(:id)
      expect(first_job).to respond_to(:name)
      expect(first_job.id).to eq(1)
    end

    it "iterates all resources across pages" do
      collection = client.jobs(per_page: 2)
      all_ids = collection.map(&:id)
      expect(all_ids).to eq([1, 2, 3])
    end
  end
end
