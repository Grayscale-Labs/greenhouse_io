# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require 'link-header-parser'

require 'greenhouse_io/api/resource_collection/page'

module GreenhouseIo
  class ResourceCollection
    class LazyPaginator
      include Enumerable

      attr_accessor :resource_collection, :query_params, :dehydrate_after_iteration

      delegate :client, :resource_class, to: :resource_collection

      # @param dehydrate_after_iteration [Boolean] When true, we try to keep only `:dehydrated` around in the hydration arrays
      def initialize(resource_collection:, query_params:, dehydrate_after_iteration: true)
        self.resource_collection = resource_collection
        self.query_params        = query_params
        self.hydrated_resources  = []
        self.hydrated_pages      = []
        self.dehydrate_after_iteration = dehydrate_after_iteration
      end

      def each_page
        return enum_for(:each_page) unless block_given?

        i = 0
        loop do
          if hydrated_pages.length == i
            num_added_resources = request_next_page!
            break if num_added_resources.zero?
          end

          yield hydrated_pages[i]
          i += 1
        end
        hydrated_pages
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
          hydrated_resources[i] = :dehydrated if dehydrate_after_iteration
          i += 1
        end

        hydrated_resources
      end

      private

      attr_accessor :hydrated_resources, :hydrated_pages, :next_page_url, :all_pages_requested

      # returns # of new resources
      def request_next_page!
        return 0 if all_pages_requested?

        # "cache" this value before we update `next_page_url`, so we can provide it to the Page instance
        new_page_url = next_page_url
        # TODO: have lower-level methods (e.g. #get_from_harvest_api) implement retries
        resp_arr = client.with_retries do
          if new_page_url.present?
            client.get_from_harvest_api(new_page_url)
          else
            # If the id is part of the params, bring it out and append to URL
            ending = client.path_id(query_params[:id])
            client.get_from_harvest_api("#{resource_class::ENDPOINT}#{ending}", query_params.except(:id))
          end
        end

        links = LinkHeaderParser.parse(client.link.to_s, base: client.class.base_uri)
        self.next_page_url       = links.find { |link| link.relation_types == ['next'] }&.target_uri
        self.all_pages_requested = next_page_url.nil?

        # If the response only returns one element, then
        # it does not return it in a list. This if checks
        # for that and wraps the singular result in an array.
        if resp_arr.is_a? Hash
          resp_arr = [resp_arr]
        end

        # e.g. [...].map { |resource_hash| GreenhouseIo::Application.new(resource_hash) }
        results = resp_arr.map { |resource_hash| resource_class.new(resource_hash) }
        hydrated_resources.push(*results)
        new_page = Page.new(results, dehydrate_after_iteration: dehydrate_after_iteration, url: new_page_url)
        hydrated_pages.push(new_page)

        resp_arr.length
      end

      def all_pages_requested?
        !!all_pages_requested
      end
    end

    private_constant :LazyPaginator
  end
end
