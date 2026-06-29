# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GreenhouseIo::V3::PartnerTokenManager do
  let(:token_store) { {} }
  let(:manager) do
    described_class.new(
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      token_store: token_store
    )
  end

  describe "#access_token" do
    context "when token_store has a valid token" do
      before do
        token_store[:access_token] = "cached_token"
        token_store[:expires_at] = (Time.now + 3600).iso8601
      end

      it "returns the cached token without making a request" do
        expect(HTTParty).not_to receive(:post)
        expect(manager.access_token).to eq("cached_token")
      end
    end

    context "when token is expired and refresh_token exists" do
      before do
        token_store[:access_token] = "expired_token"
        token_store[:expires_at] = (Time.now - 60).iso8601
        token_store[:refresh_token] = "stored_refresh_token"

        stub_request(:post, "https://auth.greenhouse.io/token")
          .with(body: { "grant_type" => "refresh_token", "refresh_token" => "stored_refresh_token" })
          .to_return(
            status: 200,
            body: { access_token: "refreshed_token", refresh_token: "rotated_refresh", expires_at: (Time.now + 3600).iso8601 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "refreshes the token and stores the rotated refresh token" do
        expect(manager.access_token).to eq("refreshed_token")
        expect(token_store[:access_token]).to eq("refreshed_token")
        expect(token_store[:refresh_token]).to eq("rotated_refresh")
      end
    end

    context "when no refresh token is present" do
      before do
        token_store[:access_token] = "expired_token"
        token_store[:expires_at] = (Time.now - 60).iso8601
        # no refresh_token
      end

      it "raises ReauthorizationRequired without making a request" do
        expect(HTTParty).not_to receive(:post)
        expect { manager.access_token }.to raise_error(GreenhouseIo::ReauthorizationRequired)
      end
    end

    context "when refresh fails" do
      before do
        token_store[:access_token] = "expired_token"
        token_store[:expires_at] = (Time.now - 60).iso8601
        token_store[:refresh_token] = "bad_refresh_token"

        stub_request(:post, "https://auth.greenhouse.io/token")
          .with(body: { "grant_type" => "refresh_token", "refresh_token" => "bad_refresh_token" })
          .to_return(status: 400, body: '{"error":"invalid_grant"}')
      end

      it "raises ReauthorizationRequired" do
        expect { manager.access_token }.to raise_error(GreenhouseIo::ReauthorizationRequired)
      end
    end
  end

  describe "#force_refresh!" do
    context "on success" do
      before do
        token_store[:access_token] = "old_token"
        token_store[:expires_at] = (Time.now + 3600).iso8601
        token_store[:refresh_token] = "stored_refresh_token"

        stub_request(:post, "https://auth.greenhouse.io/token")
          .with(body: { "grant_type" => "refresh_token", "refresh_token" => "stored_refresh_token" })
          .to_return(
            status: 200,
            body: { access_token: "force_refreshed", refresh_token: "rotated_refresh", expires_at: (Time.now + 3600).iso8601 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "refreshes even when token is still valid" do
        manager.force_refresh!
        expect(token_store[:access_token]).to eq("force_refreshed")
      end
    end

    context "on failure" do
      before do
        token_store[:refresh_token] = "bad_refresh_token"

        stub_request(:post, "https://auth.greenhouse.io/token")
          .with(body: { "grant_type" => "refresh_token", "refresh_token" => "bad_refresh_token" })
          .to_return(status: 400, body: '{"error":"invalid_grant"}')
      end

      it "raises ReauthorizationRequired" do
        expect { manager.force_refresh! }.to raise_error(GreenhouseIo::ReauthorizationRequired)
      end
    end
  end
end
