# frozen_string_literal: true

require 'hashie'

module GreenhouseIo
  class Resource
    def initialize(source_hash = {})
      self.mash = Hashie::Mash.new(source_hash)
    end

    def method_missing(method, *args, &block)
      return mash.public_send(method, *args, &block) if mash.respond_to?(method)

      super
    end

    def respond_to_missing?(method, __include_private = false)
      mash.respond_to?(method) || super
    end

    private

    attr_accessor :mash
  end
end
