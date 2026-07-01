require 'httparty'
require 'json'
require 'base64'
require 'time'

module GreenhouseIo
  module V3
    # Shared token-request/credential behavior for V3 token managers.
    # Subclasses set @client_id, @client_secret, and @token_store, and
    # implement the grant-specific #refresh! / #force_refresh! flows.
    class BaseTokenManager
      AUTH_BASE_URI = "https://auth.greenhouse.io".freeze

      # Seconds of remaining lifetime below which a cached token is treated
      # as expired, so it is refreshed before it can lapse mid-request.
      REFRESH_BUFFER = 30

      attr_reader :client_id, :client_secret, :token_store

      private

      def token_valid?
        token_store[:access_token] &&
          token_store[:expires_at] &&
          Time.parse(token_store[:expires_at]) > Time.now + REFRESH_BUFFER
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
