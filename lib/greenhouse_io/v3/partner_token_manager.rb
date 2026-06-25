require 'httparty'
require 'json'
require 'base64'
require 'time'

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
    class PartnerTokenManager
      AUTH_BASE_URI = "https://auth.greenhouse.io".freeze

      attr_reader :client_id, :client_secret, :token_store

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

      def token_valid?
        token_store[:access_token] &&
          token_store[:expires_at] &&
          Time.parse(token_store[:expires_at]) > Time.now + 30
      end

      def refresh!
        response = post_token_request(
          "grant_type" => "refresh_token",
          "refresh_token" => token_store[:refresh_token]
        )
        store_token_response(response)
      rescue GreenhouseIo::Error => e
        raise GreenhouseIo::ReauthorizationRequired.new(e.message, e.code)
      end

      def post_token_request(params)
        response = HTTParty.post(
          "#{AUTH_BASE_URI}/token",
          body: params,
          headers: { "Authorization" => "Basic #{encoded_credentials}" }
        )

        unless response.success?
          raise GreenhouseIo::Error.new(response.body, response.code)
        end

        JSON.parse(response.body)
      end

      def store_token_response(response)
        token_store[:access_token] = response["access_token"]
        token_store[:refresh_token] = response["refresh_token"]
        token_store[:expires_at] = response["expires_at"]
      end

      def encoded_credentials
        Base64.strict_encode64("#{client_id}:#{client_secret}")
      end
    end
  end
end
