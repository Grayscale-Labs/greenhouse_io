# frozen_string_literal: true

require 'greenhouse_io/v3/base_client'
require 'greenhouse_io/v3/custom_token_manager'

module GreenhouseIo
  module V3
    # Client for Greenhouse Custom Integrations. Authenticates via the
    # client_credentials grant (on behalf of `sub`), with refresh-token
    # fallback handled by CustomTokenManager.
    class CustomClient < BaseClient
      def initialize(client_id:, client_secret:, sub:, token_store: {}, on_rate_limit_budget: nil)
        super(on_rate_limit_budget: on_rate_limit_budget)
        @token_manager = CustomTokenManager.new(
          client_id: client_id,
          client_secret: client_secret,
          sub: sub,
          token_store: token_store
        )
      end
    end
  end
end
