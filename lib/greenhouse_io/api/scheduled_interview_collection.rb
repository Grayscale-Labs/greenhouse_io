# frozen_string_literal: true

require 'greenhouse_io/api/candidate'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class ScheduledInterviewCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: ScheduledInterview)
      super
    end
  end
end
