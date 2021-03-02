# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require 'link-header-parser'

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

    attr_accessor :client, :query_params, :resource_class

    def initialize(client:, query_params: {}, resource_class:)
      self.client             = client
      self.query_params       = query_params
      self.resource_class     = resource_class # e.g. GreenhouseIo::Application
      self.hydrated_resources = []
    end

    def each
      return enum_for(:each) unless block_given?

      i = 0
      loop do
        if hydrated_resources.length == i
          num_added_resources = request_next_page!
          break if num_added_resources.zero?
        end

        yield hydrated_resources[i]
        i += 1
      end
    end

    # Array#count is more efficient than Enum#count, so we want to utilize it if pagination has already been done to
    #   completion
    def count(*args, &block)
      return super unless all_pages_requested?

      hydrated_resources.count(*args, &block)
    end

    def method_missing(method, *args, &block)
      if hydrated_resources.respond_to?(method)
        each() { } unless all_pages_requested? # force a full hydration
        return hydrated_resources.public_send(method, *args, &block)
      end

      super
    end

    def respond_to_missing?(method, __include_private = false)
      hydrated_resources.respond_to?(method) || super
    end

    private

    attr_accessor :hydrated_resources, :next_page_url, :all_pages_requested

    # returns # of new resources
    def request_next_page!
      return 0 if all_pages_requested?

      # TODO: have lower-level methods (e.g. #get_from_harvest_api) implement retries
      resp_arr = client.with_retries do
        if next_page_url.present?
          client.get_from_harvest_api(next_page_url)
        else
          # e.g. client.applications(nil, query_params)
          client.public_send(resource_class.name.demodulize.tableize, nil, query_params)
        end
      end

      links = LinkHeaderParser.parse(client.link.to_s, base: client.class.base_uri)
      self.next_page_url       = links.find { |link| link.relation_types == ['next'] }&.target_uri
      self.all_pages_requested = next_page_url.nil?

      # e.g. [...].map { |resource_hash| GreenhouseIo::Application.new(resource_hash) }
      hydrated_resources.push(*resp_arr.map { |resource_hash| resource_class.new(resource_hash) })

      resp_arr.length
    end

    def all_pages_requested?
      !!all_pages_requested
    end
  end
end
