# frozen_string_literal: true

require 'greenhouse_io/api/job_stage'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class JobStageCollection < ResourceCollection
    def initialize(*args, **kw_args)
      query_params = kw_args.fetch(:query_params, {})
      if (job_id = query_params[:job_id]).present?
        endpoint = "/jobs/#{job_id}/stages"
      end
      kw_args.merge!(
        endpoint:       endpoint,
        query_params:   query_params.except(:job_id),
        resource_class: JobStage
      )
      super
    end
  end
end
