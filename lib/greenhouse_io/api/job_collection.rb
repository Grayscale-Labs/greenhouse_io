# frozen_string_literal: true

require 'greenhouse_io/api/job'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class JobCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: Job)
      super
    end
  end
end
