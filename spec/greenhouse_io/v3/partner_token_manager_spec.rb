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

  describe "#access_token with a locking store" do
    let(:locking_store) do
      # on_reload simulates another process having refreshed while we waited
      # for the lock: it mutates @data when #reload is called.
      Class.new do
        attr_reader :lock_calls, :reload_calls, :data
        def initialize(data, on_reload)
          @data = data
          @on_reload = on_reload
          @lock_calls = 0
          @reload_calls = 0
        end
        def [](k)
          @data[k]
        end
        def []=(k, v)
          @data[k] = v
        end
        def with_refresh_lock
          @lock_calls += 1
          yield
        end
        def reload
          @reload_calls += 1
          @data.merge!(@on_reload) if @on_reload
        end
      end.new(store_data, on_reload)
    end

    let(:on_reload) { nil }

    let(:manager) do
      described_class.new(
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        token_store: locking_store
      )
    end

    context "when token is expired" do
      let(:store_data) do
        { refresh_token: "stored_refresh_token", access_token: "old", expires_at: (Time.now - 60).iso8601 }
      end

      before do
        stub_request(:post, "https://auth.greenhouse.io/token")
          .with(body: { "grant_type" => "refresh_token", "refresh_token" => "stored_refresh_token" })
          .to_return(
            status: 200,
            body: { access_token: "refreshed_token", refresh_token: "rotated", expires_at: (Time.now + 3600).iso8601 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "refreshes inside the lock and reloads first" do
        expect(manager.access_token).to eq("refreshed_token")
        expect(locking_store.lock_calls).to eq(1)
        expect(locking_store.reload_calls).to eq(1)
      end
    end

    context "when another process refreshed the token while we waited for the lock" do
      # We enter with a stale/expired token; reload reveals a DIFFERENT, valid
      # token that another process stored. We should skip our own HTTP refresh.
      let(:store_data) do
        { refresh_token: "stored_refresh_token", access_token: "old", expires_at: (Time.now - 60).iso8601 }
      end
      let(:on_reload) do
        { access_token: "other_process_token", expires_at: (Time.now + 3600).iso8601 }
      end

      it "acquires the lock, reloads, and skips the HTTP refresh" do
        manager.send(:refresh!)
        expect(locking_store.lock_calls).to eq(1)
        expect(locking_store.reload_calls).to eq(1)
        expect(WebMock).not_to have_requested(:post, "https://auth.greenhouse.io/token")
      end
    end

    context "when force_refresh! is called with an unexpired but rejected token (401 path)" do
      # token_valid? is true (not expired) but Greenhouse rejected it, so the
      # 401 retry calls force_refresh!. reload does NOT change the token (no
      # other process refreshed), so we must actually refresh -- not skip.
      let(:store_data) do
        { refresh_token: "stored_refresh_token", access_token: "rejected_but_unexpired", expires_at: (Time.now + 3600).iso8601 }
      end

      before do
        stub_request(:post, "https://auth.greenhouse.io/token")
          .with(body: { "grant_type" => "refresh_token", "refresh_token" => "stored_refresh_token" })
          .to_return(
            status: 200,
            body: { access_token: "refreshed_token", refresh_token: "rotated", expires_at: (Time.now + 3600).iso8601 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "actually refreshes despite the token being unexpired" do
        manager.force_refresh!
        expect(WebMock).to have_requested(:post, "https://auth.greenhouse.io/token")
        expect(locking_store[:access_token]).to eq("refreshed_token")
      end
    end
  end
end
