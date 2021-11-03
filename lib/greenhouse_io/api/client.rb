require 'greenhouse_io/api/application_collection'
require 'greenhouse_io/api/candidate_collection'
require 'greenhouse_io/api/scheduled_interview_collection'
require 'greenhouse_io/api/job_collection'
require 'greenhouse_io/api/user_collection'

require 'retriable'

module GreenhouseIo
  class Client
    include HTTMultiParty
    include GreenhouseIo::API

    RETRIABLE_ERRORS_REGEXP = /\A
      429 | # rate-limiting
      5\d\d # 5xx errors
    \z/x.freeze

    attr_accessor :api_token, :rate_limit, :rate_limit_remaining, :link
    base_uri 'https://harvest.greenhouse.io/v1'

    def initialize(api_token = nil)
      @api_token = api_token || GreenhouseIo.configuration.api_token
      self.using_with_retries = false
    end

    def offices(id = nil, options = {})
      get_from_harvest_api "/offices#{path_id(id)}", options
    end

    def offers(id = nil, options = {})
      get_from_harvest_api "/offers#{path_id(id)}", options
    end

    def departments(id = nil, options = {})
      get_from_harvest_api "/departments#{path_id(id)}", options
    end

    def candidates(options = {})
      get_resource GreenhouseIo::CandidateCollection, options
    end

    def activity_feed(id, options = {})
      get_from_harvest_api "/candidates/#{id}/activity_feed", options
    end

    def create_candidate(hash, on_behalf_of)
      post_to_harvest_api(
        '/candidates',
        hash,
        { 'On-Behalf-Of' => on_behalf_of.to_s }
      )
    end

    def create_prospect(hash, on_behalf_of)
      post_to_harvest_api(
        '/prospects',
        hash,
        { 'On-Behalf-Of' => on_behalf_of.to_s }
      )
    end

    def create_candidate_note(candidate_id, note_hash, on_behalf_of)
      post_to_harvest_api(
        "/candidates/#{candidate_id}/activity_feed/notes",
        note_hash,
        { 'On-Behalf-Of' => on_behalf_of.to_s }
      )
    end

    def applications(options = {})
      get_resource GreenhouseIo::ApplicationCollection, options
    end

    def offers_for_application(id, options = {})
      get_from_harvest_api "/applications/#{id}/offers", options
    end

    def current_offer_for_application(id, options = {})
      get_from_harvest_api "/applications/#{id}/offers/current_offer", options
    end

    def scorecards(id, options = {})
      get_from_harvest_api "/applications/#{id}/scorecards", options
    end

    def all_scorecards(id = nil, options = {})
      get_from_harvest_api "/scorecards/#{id}", options
    end

    def scheduled_interviews(options = {})
      get_resource GreenhouseIo::ScheduledInterviewCollection, options
    end

    def jobs(options = {})
      get_resource GreenhouseIo::JobCollection, options
    end

    def stages(id, options = {})
      get_from_harvest_api "/jobs/#{id}/stages", options
    end

    def job_post(id, options = {})
      get_from_harvest_api "/jobs/#{id}/job_post", options
    end

    def users(options = {})
      get_resource GreenhouseIo::UserCollection, options
    end

    def sources(id = nil, options = {})
      get_from_harvest_api "/sources#{path_id(id)}", options
    end

    def get_from_harvest_api(url, options = {})
      response = get_response(url, query: options, basic_auth: basic_auth)

      set_headers_info(response.headers)

      if response.code == 200
        parse_json(response)
      else
        raise GreenhouseIo::Error.new(response.code)
      end
    end

    def post_to_harvest_api(url, body, headers)
      response = post_response(url, {
        :body => JSON.dump(body),
        :basic_auth => basic_auth,
        :headers => headers
      })

      set_headers_info(response.headers)

      if response.success?
        parse_json(response)
      else
        raise GreenhouseIo::Error.new(response.code)
      end
    end

    def with_retries(retry_options={ on: { GreenhouseIo::Error => RETRIABLE_ERRORS_REGEXP } })
      return yield if using_with_retries

      begin
        # Eventually we want to have lower-level methods like #get_from_harvest_api implement retries automatically
        # So let's disallow nested `with_retries` blocks just in case we add it there but forget to remove it from
        #   higher-level methods
        self.using_with_retries = true

        Retriable.retriable(retry_options) do
          yield
        end
      ensure
        self.using_with_retries = false
      end
    end

    def path_id(id = nil)
      "/#{id}" unless id.nil?
    end

    private

    attr_accessor :using_with_retries # see #with_retries

    def get_resource(resource_class, options)
      resource_collection = resource_class.new(client: self, query_params: options)

      # Options hash must use symbols as keys!
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
  end
end
