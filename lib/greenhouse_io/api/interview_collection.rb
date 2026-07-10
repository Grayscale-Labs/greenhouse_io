# frozen_string_literal: true

require 'greenhouse_io/api/interview'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  # Collection for Harvest v3 `/interviews`. Unlike v1's ScheduledInterviewCollection, v3 has no
  #   nested `/applications/:id/interviews` route — callers filter by the `application_ids` query
  #   param instead — so this is a plain collection over the flat endpoint.
  class InterviewCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: Interview)
      super
    end
  end
end
