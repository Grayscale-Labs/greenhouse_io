require 'greenhouse_io/v3/base_token_manager'

module GreenhouseIo
  module V3
    # Handles the OAuth 2.0 Authorization Code Grant token lifecycle
    # (post-authorization) for Partner integrations.
    #
    # Unlike CustomTokenManager, this cannot self-heal: there is no
    # client_credentials fetch fallback. The refresh token rotates on every
    # refresh, so the new one must be persisted. When refresh fails, the
    # failure is terminal until the user re-authorizes through Greenhouse, so
    # a ReauthorizationRequired error is raised.
    class PartnerTokenManager < BaseTokenManager
      def initialize(client_id:, client_secret:, token_store:)
        @client_id = client_id
        @client_secret = client_secret
        @token_store = token_store
      end

      def access_token
        refresh! unless token_valid?
        token_store[:access_token]
      end

      def force_refresh!
        refresh!
      end

      private

      def refresh!
        # No refresh token means the user was never authorized (or it was
        # revoked/wiped) -- a terminal state. Fail fast without a doomed
        # network call.
        if token_store[:refresh_token].to_s.empty?
          raise GreenhouseIo::ReauthorizationRequired.new("No refresh token available")
        end

        request_refresh!
      end

      def request_refresh!
        response = post_token_request(
          "grant_type" => "refresh_token",
          "refresh_token" => token_store[:refresh_token]
        )
        store_token_response(response)
      rescue GreenhouseIo::Error => e
        raise GreenhouseIo::ReauthorizationRequired.new(e.message, e.code)
      end
    end
  end
end
