# frozen_string_literal: true

require 'greenhouse_io/api/user'
require 'greenhouse_io/api/resource_collection'

module GreenhouseIo
  class UserCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: User)
      super
    end
  end
end
