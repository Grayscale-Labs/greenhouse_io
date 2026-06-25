# frozen_string_literal: true

require 'greenhouse_io/v3/base_client'
require 'greenhouse_io/v3/partner_token_manager'

module GreenhouseIo
  module V3
    # Client for Greenhouse Partner Integrations. Authenticates via the
    # OAuth 2.0 Authorization Code Grant, with refresh handled by
    # PartnerTokenManager. There is no `sub`, and token_store is required
    # since Partner clients always need persisted tokens.
    class PartnerClient < BaseClient
      def initialize(client_id:, client_secret:, token_store:)
        super()
        @token_manager = PartnerTokenManager.new(
          client_id: client_id,
          client_secret: client_secret,
          token_store: token_store
        )
      end
    end
  end
end
