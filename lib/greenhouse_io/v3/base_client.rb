# frozen_string_literal: true

require 'greenhouse_io/api/application_collection'
require 'greenhouse_io/api/candidate_collection'
require 'greenhouse_io/api/scheduled_interview_collection'
require 'greenhouse_io/api/job_collection'
require 'greenhouse_io/api/job_post_collection'
require 'greenhouse_io/api/job_stage_collection'
require 'greenhouse_io/api/user_collection'

require 'retriable'

module GreenhouseIo
  module V3
    # Shared HTTP/API behavior for V3 clients. Subclasses must set
    # @token_manager in their #initialize (calling super to set up the
    # shared request state).
    class BaseClient
      include HTTMultiParty
      include GreenhouseIo::API

      RETRIABLE_ERRORS_REGEXP = /\A5\d\d\z/x.freeze

      attr_accessor :rate_limit, :rate_limit_remaining, :link

      base_uri 'https://harvest.greenhouse.io/v3'

      def initialize
        @token_refreshed_this_request = false
        self.using_with_retries = false
      end

      def jobs(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::JobCollection, params, **kw_args)
      end

      def candidates(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::CandidateCollection, params, **kw_args)
      end

      def applications(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::ApplicationCollection, params, **kw_args)
      end

      def users(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::UserCollection, params, **kw_args)
      end

      def job_stages(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::JobStageCollection, params, **kw_args)
      end

      def job_posts(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::JobPostCollection, params, **kw_args)
      end

      def interviews(options = {})
        kw_args, params = normalize_options(options)
        get_resource(GreenhouseIo::ScheduledInterviewCollection, params, **kw_args)
      end

      def get_from_harvest_api(url, options = {})
        response = get_response(url, query: options, headers: bearer_auth_header)

        set_headers_info(response.headers)

        if response.code == 200
          parse_json(response)
        elsif response.code == 401 && !@token_refreshed_this_request
          @token_refreshed_this_request = true
          @token_manager.force_refresh!
          begin
            get_from_harvest_api(url, options)
          ensure
            @token_refreshed_this_request = false
          end
        else
          raise GreenhouseIo::Error.new(response.code)
        end
      end

      def post_to_harvest_api(url, body, headers = {})
        response = post_response(url, {
          body: JSON.dump(body),
          headers: json_headers(headers)
        })

        set_headers_info(response.headers)

        if response.success?
          parse_json(response)
        elsif response.code == 401 && !@token_refreshed_this_request
          @token_refreshed_this_request = true
          @token_manager.force_refresh!
          begin
            post_to_harvest_api(url, body, headers)
          ensure
            @token_refreshed_this_request = false
          end
        else
          raise GreenhouseIo::Error.new(response.code)
        end
      end

      def patch_to_harvest_api(url, body, headers = {})
        response = patch_response(url, {
          body: JSON.dump(body),
          headers: json_headers(headers)
        })

        set_headers_info(response.headers)

        if response.success?
          parse_json(response)
        elsif response.code == 401 && !@token_refreshed_this_request
          @token_refreshed_this_request = true
          @token_manager.force_refresh!
          begin
            patch_to_harvest_api(url, body, headers)
          ensure
            @token_refreshed_this_request = false
          end
        else
          raise GreenhouseIo::Error.new(response.code)
        end
      end

      # Webhook management (partners-exclusive). See https://harvestdocs.greenhouse.io.
      def list_webhooks(options = {})
        get_from_harvest_api('/webhooks', options)
      end

      def create_webhook(attributes)
        post_to_harvest_api('/webhooks', attributes)
      end

      def update_webhook(id, attributes)
        patch_to_harvest_api("/webhooks#{path_id(id)}", attributes)
      end

      def with_retries(retry_options = { on: { GreenhouseIo::Error => RETRIABLE_ERRORS_REGEXP } })
        return yield if using_with_retries

        begin
          self.using_with_retries = true
          Retriable.retriable(retry_options) { yield }
        ensure
          self.using_with_retries = false
        end
      end

      def path_id(id = nil)
        "/#{id}" unless id.nil?
      end

      private

      attr_accessor :using_with_retries

      def bearer_auth_header
        { "Authorization" => "Bearer #{@token_manager.access_token}" }
      end

      # Bearer auth + JSON content type for write requests. An explicit header wins if supplied.
      def json_headers(headers)
        bearer_auth_header.merge("Content-Type" => "application/json").merge(headers)
      end

      def get_resource(resource_class, options, dehydrate_after_iteration: true)
        resource_collection = resource_class.new(
          client: self,
          query_params: options,
          dehydrate_after_iteration: dehydrate_after_iteration
        )

        if options.has_key?(:id)
          resource_collection.first
        else
          resource_collection
        end
      end

      def set_headers_info(headers)
        self.rate_limit = headers['x-ratelimit-limit'].to_i
        self.rate_limit_remaining = headers['x-ratelimit-remaining'].to_i
        self.link = headers['link'].to_s
      end

      def normalize_options(options)
        kw_arg_keys = %i[dehydrate_after_iteration]
        kw_args, params = options.slice(*kw_arg_keys), options.except(*kw_arg_keys)

        params.each do |key, value|
          if value.respond_to?(:iso8601)
            params[key] = value.iso8601
          end
        end

        [kw_args, params]
      end
    end
  end
end
