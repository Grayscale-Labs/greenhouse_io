# frozen_string_literal: true

require 'greenhouse_io/api/candidate'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class CandidateCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: Candidate)
      super
    end
  end
end
