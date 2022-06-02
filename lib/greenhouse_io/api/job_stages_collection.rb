# frozen_string_literal: true

require 'greenhouse_io/api/job_stages'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class JobStagesCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: JobStages)
      super
    end
  end
end
