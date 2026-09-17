# frozen_string_literal: true

module GreenhouseIo
  class Error < StandardError
    attr_reader :code, :headers

    def initialize(message, code = nil, headers: nil)
      super message
      @code = code
      @headers = normalize_headers(headers)
    end

    private

    # Keys are downcased and values flattened to one string, so lookups must use a lowercase key.
    def normalize_headers(headers)
      return {} unless headers.respond_to?(:to_h)

      headers.to_h.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_s.downcase] = Array(value).join(', ')
      end
    end
  end

  # Raised when a Partner refresh token is expired or invalid (24-hour TTL
  # passed, already used, or revoked). Signals to the consumer that the user
  # must re-authorize through the Greenhouse OAuth consent flow.
  class ReauthorizationRequired < Error; end
end
