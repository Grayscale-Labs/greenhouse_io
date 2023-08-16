# frozen_string_literal: true

require 'greenhouse_io/api/scheduled_interview'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class ScheduledInterviewCollection < ResourceCollection
    def initialize(*args, **kw_args)
      query_params = kw_args.fetch(:query_params, {})
      if (application_id = query_params[:application_id]).present?
        endpoint = "/applications/#{application_id}#{ScheduledInterview::DEFAULT_ENDPOINT}"
      end
      kw_args.merge!(
        endpoint:       endpoint,
        query_params:   query_params.except(:application_id),
        resource_class: ScheduledInterview
      )
      super
    end
  end
end
