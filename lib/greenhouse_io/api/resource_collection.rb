# frozen_string_literal: true

require 'greenhouse_io/api/resource_collection/lazy_paginator'

module GreenhouseIo
  # This class does lazy pagination, but otherwise quacks like an Array by delegating method calls to
  #   its `hydrated_resources` internal Array.
  #
  # Lazy pagination allows for (e.g.):
  #   `collection.each.with_index { |resource, i| puts resource.id; break if i == 0; }`
  #
  #   That ^^ will only request the first page, regardless of whether subsequent pages exist or not.
  #
  # Note, however, that if a non-Enum Array method is used (e.g. #[], #length) and full pagination hasn't been done yet,
  #   pagination is first done to completion before delegating the method call to the internal Array.
  class ResourceCollection
    include Enumerable

    attr_accessor :client, :resource_class, :dehydrate_after_iteration

    # @param dehydrate_after_iteration [Boolean] When true, we try to keep only `:dehydrated` around in the hydration arrays
    def initialize(client:, query_params: {}, resource_class:, dehydrate_after_iteration: true)
      self.client             = client
      self.resource_class     = resource_class # e.g. GreenhouseIo::Application
      self.lazy_paginators    = [LazyPaginator.new(resource_collection: self, query_params: query_params)]
      self.hydrated_resources = []
      self.hydrated_pages     = []
      self.dehydrate_after_iteration = dehydrate_after_iteration
    end

    def each_page
      return enum_for(:each_page) unless block_given?

      i = 0
      lazy_paginators.each do |lazy_paginator|
        lazy_paginator.each_page do |page|
          hydrated_pages.push(page) if hydrated_pages.length == i
          hydrated_resources.push(*page.contents)
          yield page
          i += 1
        end
      end

      self.all_resources_hydrated = true

      hydrated_pages
    end

    def each
      return enum_for(:each) unless block_given?

      i = 0
      lazy_paginators.each do |lazy_paginator|
        lazy_paginator.each do |resource|
          to_store = dehydrate_after_iteration ? :dehydrated : resource
          hydrated_resources << to_store if hydrated_resources.length == i
          yield resource
          i += 1
        end
      end

      self.all_resources_hydrated = true

      hydrated_resources
    end

    # Array#count is more efficient than Enum#count, so we want to utilize it if pagination has already been done to
    #   completion
    def count(*args, &block)
      return super unless all_resources_hydrated?

      hydrated_resources.count(*args, &block)
    end

    def merge!(other)
      if self.class != other.class
        raise "Cannot merge #{other.class} (resource_type: #{other.resource_type}) with #{self.class} "\
              "(resource_type: #{resource_type})"
      end

      lazy_paginators.push(*other.lazy_paginators)
      hydrated_resources.push(*other.hydrated_resources)
      self.all_resources_hydrated = false unless (all_resources_hydrated? && other.all_resources_hydrated?)

      self
    end

    def method_missing(method, *args, &block)
      if hydrated_resources.respond_to?(method)
        each() { } unless all_resources_hydrated? # force a full hydration
        return hydrated_resources.public_send(method, *args, &block)
      end

      super
    end

    def respond_to_missing?(method, __include_private = false)
      hydrated_resources.respond_to?(method) || super
    end

    protected

    attr_accessor :lazy_paginators, :hydrated_resources, :hydrated_pages, :all_resources_hydrated

    def all_resources_hydrated?
      !!all_resources_hydrated
    end
  end
end
