# frozen_string_literal: true

require 'greenhouse_io/api/resource'

module GreenhouseIo
  class User < Resource
    ENDPOINT = "/users"
  end
end
