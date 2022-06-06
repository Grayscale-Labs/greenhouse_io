# frozen_string_literal: true

require 'greenhouse_io/api/job_stage'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class JobStageCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: JobStage)
      super
    end
  end
end
