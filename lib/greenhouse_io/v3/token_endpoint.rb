# frozen_string_literal: true

require 'httparty'
require 'json'
require 'base64'

module GreenhouseIo
  module V3
    TokenPair = Struct.new(:access_token, :refresh_token, :expires_at, :token_type, keyword_init: true)

    # Stateless transport for https://auth.greenhouse.io/token. Persistence,
    # refresh timing and concurrency are the consumer's concern.
    class TokenEndpoint
      AUTH_BASE_URI = 'https://auth.greenhouse.io'.freeze

      # Greenhouse invalidates the old refresh token the instant it issues a new
      # one, so an exchange whose response we never see is unrecoverable.
      DEFAULT_TIMEOUT = 10

      def initialize(client_id:, client_secret:, timeout: DEFAULT_TIMEOUT)
        @client_id = client_id
        @client_secret = client_secret
        @timeout = timeout
      end

      def exchange_refresh_token(refresh_token)
        to_pair(request('grant_type' => 'refresh_token', 'refresh_token' => refresh_token))
      end

      # Greenhouse does not require redirect_uri on this grant.
      def exchange_authorization_code(code)
        to_pair(request('grant_type' => 'authorization_code', 'code' => code))
      end

      def fetch_client_credentials(sub:)
        to_pair(request('grant_type' => 'client_credentials', 'sub' => sub))
      end

      # Parsed response body. Prefer the typed helpers above; this is public so
      # the stateful token managers share one HTTP implementation.
      def request(params)
        response = HTTParty.post(
          "#{AUTH_BASE_URI}/token",
          body: params,
          headers: {
            'Authorization' => "Basic #{encoded_credentials}",
            'Content-Type' => 'application/x-www-form-urlencoded'
          },
          timeout: @timeout
        )

        unless response.success?
          raise GreenhouseIo::Error.new(response.body, response.code, headers: response.headers)
        end

        JSON.parse(response.body)
      end

      private

      def to_pair(body)
        TokenPair.new(
          access_token: body['access_token'],
          refresh_token: body['refresh_token'],
          expires_at: body['expires_at'],
          token_type: body['token_type']
        )
      end

      def encoded_credentials
        Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      end
    end
  end
end
