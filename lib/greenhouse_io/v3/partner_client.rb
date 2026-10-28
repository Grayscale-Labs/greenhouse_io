# frozen_string_literal: true

require 'greenhouse_io/v3/base_client'
require 'greenhouse_io/v3/partner_token_manager'

module GreenhouseIo
  module V3
    # Client for Greenhouse Partner Integrations. Authenticates via the
    # OAuth 2.0 Authorization Code Grant. There is no `sub`, and tokens are
    # always persisted -- either by an injected token_manager or by the
    # built-in PartnerTokenManager over a token_store.
    class PartnerClient < BaseClient
      # Pass `token_manager:` to own the token lifecycle yourself; it need only
      # respond to #access_token and #force_refresh!. Omit it to keep the
      # built-in PartnerTokenManager + token_store behavior.
      def initialize(client_id: nil, client_secret: nil, token_store: nil, token_manager: nil,
                     on_rate_limit_budget: nil)
        super(on_rate_limit_budget: on_rate_limit_budget)

        if token_manager.nil? && [client_id, client_secret, token_store].any?(&:nil?)
          raise ArgumentError, 'pass token_manager:, or all of client_id:, client_secret: and token_store:'
        end

        @token_manager = token_manager || PartnerTokenManager.new(
          client_id: client_id,
          client_secret: client_secret,
          token_store: token_store
        )
      end

      # Webhook management is exclusive to partner integrations, so it lives here rather than on
      # BaseClient (custom-integration clients must not expose these). See https://harvestdocs.greenhouse.io.
      def list_webhooks(options = {})
        get_from_harvest_api('/webhooks', options)
      end

      def create_webhook(attributes)
        post_to_harvest_api('/webhooks', attributes)
      end

      def update_webhook(id, attributes)
        patch_to_harvest_api("/webhooks#{path_id(id)}", attributes)
      end
    end
  end
end
