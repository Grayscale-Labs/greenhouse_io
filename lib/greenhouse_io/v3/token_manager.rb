require 'httparty'
require 'json'
require 'base64'

module GreenhouseIo
  module V3
    class TokenManager
      AUTH_BASE_URI = "https://auth.greenhouse.io".freeze

      attr_reader :client_id, :client_secret, :sub, :token_store

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

      def token_valid?
        token_store[:access_token] &&
          token_store[:expires_at] &&
          Time.parse(token_store[:expires_at]) > Time.now + 30
      end

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
