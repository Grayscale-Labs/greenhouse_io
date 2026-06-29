require 'greenhouse_io/v3/base_token_manager'

module GreenhouseIo
  module V3
    # Token manager for Custom Integrations. Uses the client_credentials
    # grant (on behalf of `sub`), falling back to a fresh fetch when a
    # refresh fails.
    class CustomTokenManager < BaseTokenManager
      attr_reader :sub

      def initialize(client_id:, client_secret:, sub:, token_store: {})
        @client_id = client_id
        @client_secret = client_secret
        @sub = sub
        @token_store = token_store
      end

      def access_token
        return token_store[:access_token] if token_valid?

        if token_store[:refresh_token]
          refresh!
        else
          fetch!
        end

        token_store[:access_token]
      end

      def force_refresh!
        if token_store[:refresh_token]
          refresh!
        else
          fetch!
        end
      end

      private

      def fetch!
        response = post_token_request("grant_type" => "client_credentials", "sub" => sub)
        store_token_response(response)
      end

      def refresh!
        response = post_token_request(
          "grant_type" => "refresh_token",
          "refresh_token" => token_store[:refresh_token]
        )
        store_token_response(response)
      rescue GreenhouseIo::Error
        fetch!
      end
    end
  end
end
