# frozen_string_literal: true

require 'greenhouse_io/api/application'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class ApplicationCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: Application)
      super
    end
  end
end
