# frozen_string_literal: true

require 'greenhouse_io/api/job_post'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class JobPostCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: JobPost)
      super
    end
  end
end
