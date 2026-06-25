module GreenhouseIo
  class Error < StandardError
    attr_reader :code

    def initialize(message, code = nil)
      super message
      @code = code
    end
  end

  # Raised when a Partner refresh token is expired or invalid (24-hour TTL
  # passed, already used, or revoked). Signals to the consumer that the user
  # must re-authorize through the Greenhouse OAuth consent flow.
  class ReauthorizationRequired < Error; end
end
