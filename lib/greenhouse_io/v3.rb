require 'greenhouse_io/v3/base_client'
require 'greenhouse_io/v3/custom_token_manager'
require 'greenhouse_io/v3/custom_client'
require 'greenhouse_io/v3/partner_token_manager'
require 'greenhouse_io/v3/partner_client'

module GreenhouseIo
  module V3
    # Backward-compatible aliases for the pre-rename names. Existing consumers
    # can keep using V3::Client / V3::TokenManager and migrate to the explicit
    # Custom* names at their own pace.
    Client = CustomClient
    TokenManager = CustomTokenManager
  end
end
