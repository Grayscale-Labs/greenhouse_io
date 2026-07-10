# frozen_string_literal: true

require 'greenhouse_io/api/resource'

module GreenhouseIo
  # Harvest v3 "Interviews" (renamed from v1 "Scheduled Interviews"). The v3 endpoint is
  #   `/interviews`, distinct from v1's `/scheduled_interviews` (see ScheduledInterview).
  class Interview < Resource
    DEFAULT_ENDPOINT = "/interviews"
  end
end
