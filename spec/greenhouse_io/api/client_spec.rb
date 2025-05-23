# frozen_string_literal: true

require 'spec_helper'

require 'active_support/core_ext/kernel/reporting'

describe GreenhouseIo::Client do

  let(:fake_api_token) { '123FakeToken' }

  it "should have a base url for an API endpoint" do
    expect(GreenhouseIo::Client.base_uri).to eq("https://harvest.greenhouse.io/v1")
  end

  context "given an instance of GreenhouseIo::Client" do

    before do
      GreenhouseIo.configuration.symbolize_keys = true
      @client = GreenhouseIo::Client.new(fake_api_token)
    end

    describe "#initialize" do
      it "has an api_token" do
        expect(@client.api_token).to eq(fake_api_token)
      end

      it "uses the configuration value when token is not specified" do
        GreenhouseIo.configuration.api_token = '123FakeENV'
        default_client = GreenhouseIo::Client.new
        expect(default_client.api_token).to eq('123FakeENV')
      end
    end

    describe "#path_id" do
      context "given an id" do
        it "returns an id path" do
          output = @client.send(:path_id, 1)
          expect(output).to eq('/1')
        end
      end

      context "given no id" do
        it "returns nothing" do
          output = @client.send(:path_id)
          expect(output).to be_nil
        end
      end
    end

    describe "#set_headers_info" do
      before do
        VCR.use_cassette('client/headers') do
          @client.candidates.first
        end
      end

      it "sets the rate limit" do
        expect(@client.rate_limit).to eq(20)
      end

      it "sets the remaining rate limit" do
        expect(@client.rate_limit_remaining).to eq(19)
      end

      it "sets rest link" do
        expect(@client.link).to eq('<https://harvest.greenhouse.io/v1/candidates/?page=1&per_page=100>; rel="last"')
      end
    end

    describe "#offices" do
      context "given no id" do
        before do
          VCR.use_cassette('client/offices') do
            @offices_response = @client.offices
          end
        end

        it "returns a response" do
          expect(@offices_response).to_not be_nil
        end

        it "returns an array of offices" do
          expect(@offices_response).to be_an_instance_of(Array)
        end

        it "returns office details" do
          expect(@offices_response.first).to have_key(:name)
        end
      end

      context "given an id" do
        before do
          VCR.use_cassette('client/office') do
            @office_response = @client.offices(220)
          end
        end

        it "returns a response" do
          expect(@office_response).to_not be_nil
        end

        it "returns an office hash" do
          expect(@office_response).to be_an_instance_of(Hash)
        end

        it "returns an office's details" do
          expect(@office_response).to have_key(:name)
        end
      end
    end

    describe "#departments" do
      context "given no id" do
        before do
          VCR.use_cassette('client/departments') do
            @departments_response = @client.departments
          end
        end

        it "returns a response" do
          expect(@departments_response).to_not be_nil
        end

        it "returns an array of departments" do
          expect(@departments_response).to be_an_instance_of(Array)
        end

        it "returns office details" do
          expect(@departments_response.first).to have_key(:name)
        end
      end

      context "given an id" do
        before do
          VCR.use_cassette('client/department') do
            @department_response = @client.departments(187)
          end
        end

        it "returns a response" do
          expect(@department_response).to_not be_nil
        end

        it "returns a department hash" do
          expect(@department_response).to be_an_instance_of(Hash)
        end

        it "returns a department's details" do
          expect(@department_response).to have_key(:name)
        end
      end
    end

    describe '#candidates', vcr: { cassette_name: 'client/candidates' } do
      let(:method_args) { [] }

      subject(:candidates) { @client.candidates(*method_args) }

      context 'given no options' do
        it 'returns a response' do
          expect(candidates).to_not be_nil
        end

        it 'returns a CandidateCollection instance' do
          expect(candidates).to be_an_instance_of(GreenhouseIo::CandidateCollection)
        end

        it 'returns details of candidates' do
          expect(candidates.first).to have_key(:first_name)
        end
      end

      context 'given a hash with no id', :vcr do
        let(:fake_api_token) { ENV['GREENHOUSE_API_TOKEN'] }

        let(:per_page) { 1 } # Use per_page: 1 to limit data size + test pagination
        let(:method_args) { [{ job_id: 4737402002, per_page: per_page }] } # This job is fake ("Space Explorer").

        it 'returns a response' do
          expect(candidates).to_not be_nil
        end

        it 'returns a CandidateCollection instance' do
          expect(candidates).to be_an_instance_of(GreenhouseIo::CandidateCollection)
        end

        it 'returns candidate details' do
          expect(candidates.first).to respond_to(:first_name)
        end

        it 'iterates by utilizing pagination' do
          expect(candidates.first(per_page * 2).map(&:id)).to eq([68601968002, 69210188002])
        end

        context do
          before(:each) do
            allow(GreenhouseIo::Client).to receive(:get).and_return(double('success?': false, headers: {}, code: code))
          end

          context 'when 5xx encountered' do
            let(:code) { 500 }

            it 'retries' do
              expect(@client).to(receive(:get_response)).thrice.and_call_original
              suppress(GreenhouseIo::Error) { candidates.first }
            end
          end
        end

        context 'passes timestamp parameters' do
          let(:time) { Time.now }
          let(:method_args) { [{created_at: time, updated_at: time, last_activity: time}] }
          let(:get_resource) {double(get_resource)}

          before(:each) do
            allow(@client).to(receive(:get_resource)).with(GreenhouseIo::CandidateCollection, {created_at: time, updated_at: time, last_activity: time})
          end

          it 'converts times to iso8601' do
            expect(@client).to receive(:get_resource).with(GreenhouseIo::CandidateCollection, {created_at: time.iso8601, updated_at: time.iso8601, last_activity: time.iso8601}, {})
            @client.candidates(*method_args)
          end
        end
      end

      context 'given a hash with an id', vcr: { cassette_name: 'client/candidate' } do
        let(:method_args) { [{ id: 1 }] }

        subject(:candidate) { candidates }

        it 'returns a response' do
          expect(candidate).to_not be_nil
        end

        it 'returns a Candidate instance' do
          expect(candidate).to be_an_instance_of(GreenhouseIo::Candidate)
        end

        it "returns a candidate's details" do
          expect(candidate).to have_key(:first_name)
        end
      end
    end

    describe "#activity_feed" do
      before do
        VCR.use_cassette('client/activity_feed') do
          @activity_feed = @client.activity_feed(1)
        end
      end

      it "returns a response" do
        expect(@activity_feed).to_not be_nil
      end

      it "returns an activity feed" do
        expect(@activity_feed).to be_an_instance_of(Hash)
      end

      it "returns details of the activity feed" do
        expect(@activity_feed).to have_key(:activities)
      end
    end

    describe "#create_candidate_note" do
      it "posts an note for a specified candidate" do
        VCR.use_cassette('client/create_candidate_note') do
          create_candidate_note = @client.create_candidate_note(
            1,
            {
                user_id: 2,
                message: "Candidate on vacation",
                visibility: "public"
            },
            2
          )
          expect(create_candidate_note).to_not be_nil
          expect(create_candidate_note).to include :body => 'Candidate on vacation'
        end
      end

      it "errors when given invalid On-Behalf-Of id" do
        VCR.use_cassette('client/create_candidate_note_invalid_on_behalf_of') do
          expect {
            @client.create_candidate_note(
              1,
              {
                  user_id: 2,
                  message: "Candidate on vacation",
                  visibility: "public"
              },
              99
            )
          }.to raise_error(GreenhouseIo::Error)
        end
      end

      it "errors when given an invalid candidate id" do
        VCR.use_cassette('client/create_candidate_note_invalid_candidate_id') do
          expect {
            @client.create_candidate_note(
              99,
              {
                  user_id: 2,
                  message: "Candidate on vacation",
                  visibility: "public"
              },
              2
            )
          }.to raise_error(GreenhouseIo::Error)
        end
      end

      it "errors when given an invalid user_id" do
        VCR.use_cassette('client/create_candidate_note_invalid_user_id') do
          expect {
            @client.create_candidate_note(
              1,
              {
                  user_id: 99,
                  message: "Candidate on vacation",
                  visibility: "public"
              },
              2
            )
          }.to raise_error(GreenhouseIo::Error)
        end
      end

      it "errors when missing required field" do
        VCR.use_cassette('client/create_candidate_note_invalid_missing_field') do
          expect {
            @client.create_candidate_note(
              1,
              {
                  user_id: 2,
                  visibility: "public"
              },
              2
            )
          }.to raise_error(GreenhouseIo::Error)
        end
      end
    end

    describe '#applications', vcr: { cassette_name: 'client/applications' } do
      let(:method_args) { [] }

      subject(:applications) { @client.applications(*method_args) }

      context 'given an empty hash' do
        it 'returns a response' do
          expect(applications).to_not be_nil
        end

        it 'returns an ApplicationCollection instance' do
          expect(applications).to be_an_instance_of(GreenhouseIo::ApplicationCollection)
        end

        it 'returns application details' do
          expect(applications.first).to have_key(:person_id)
        end
      end

      context 'given a hash with parameters', :vcr do
        let(:fake_api_token) { ENV['GREENHOUSE_API_TOKEN'] }

        let(:per_page) { 1 } # Use per_page: 1 to limit data size + test pagination
        let(:method_args) { [{ job_id: 4737402002, per_page: per_page }] } # This job is fake ("Space Explorer").

        it 'returns a response' do
          expect(applications).to_not be_nil
        end

        it 'returns an ApplicationCollection instance' do
          expect(applications).to be_an_instance_of(GreenhouseIo::ApplicationCollection)
        end

        it 'returns application details' do
          expect(applications.first).to respond_to(:candidate_id)
        end

        it 'iterates by utilizing pagination' do
          expect(applications.first(per_page * 2).map(&:candidate_id)).to eq([68601968002, 69210188002])
        end

        context do
          before(:each) do
            allow(GreenhouseIo::Client).to receive(:get).and_return(double('success?': false, headers: {}, code: code))
          end

          context 'when 5xx encountered' do
            let(:code) { 500 }

            it 'retries' do
              expect(@client).to(receive(:get_response)).thrice.and_call_original
              suppress(GreenhouseIo::Error) { applications.first }
            end
          end
        end
      end

      context 'given a hash with an id', vcr: { cassette_name: 'client/application' } do
        let(:method_args) { [{ id: 1 }] }

        subject(:application) { applications }

        it 'returns a response' do
          expect(application).to_not be_nil
        end

        it 'returns an Application instance' do
          expect(application).to be_an_instance_of(GreenhouseIo::Application)
        end

        it "returns an application's details" do
          expect(application).to have_key(:person_id)
        end
      end

      context 'given a job_id', vcr: { cassette_name: 'client/application_by_job_id' } do
        let(:method_args) { [{ job_id: 144371 }] }

        it 'returns a response' do
          expect(applications).to_not be_nil
        end

        it 'returns an ApplicationCollection instance' do
          expect(applications).to be_an_instance_of(GreenhouseIo::ApplicationCollection)
          expect(applications.first).to be_an_instance_of(GreenhouseIo::Application)
          expect(applications.first).to have_key(:prospect)
        end
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [{applied_at: time, rejected_at: time, last_activity_at: time}] }
        let(:get_resource) {double(get_resource)}

        before(:each) do
          allow(@client).to(receive(:get_resource)).with(GreenhouseIo::ApplicationCollection, {applied_at: time, rejected_at: time, last_activity_at: time}, {})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_resource).with(GreenhouseIo::ApplicationCollection, {applied_at: time.iso8601, rejected_at: time.iso8601, last_activity_at: time.iso8601}, {})
          @client.applications(*method_args)
        end
      end
    end

    describe "#scorecards" do
      before do
        VCR.use_cassette('client/scorecards') do
          @scorecard = @client.scorecards(1)
        end
      end

      it "returns a response" do
        expect(@scorecard).to_not be_nil
      end

      it "returns an array of scorecards" do
        expect(@scorecard).to be_an_instance_of(Array)
      end

      it "returns details of the scorecards" do
        expect(@scorecard.first).to have_key(:interview)
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [1, {created_at: time, updated_at: time, interviewed_at: time, submitted_at: time}] }
        let(:get_from_harvest_api) {double(get_from_harvest_api)}

        before(:each) do
          allow(@client).to(receive(:get_from_harvest_api)).with("/applications/1/scorecards", {created_at: time, updated_at: time, interviewed_at: time, submitted_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_from_harvest_api).with("/applications/1/scorecards", {created_at: time.iso8601, updated_at: time.iso8601, interviewed_at: time.iso8601, submitted_at: time.iso8601})
          @client.scorecards(*method_args)
        end
      end
    end

    describe "#all_scorecards" do
      before do
        VCR.use_cassette('client/all_scorecards') do
          @scorecard = @client.all_scorecards
        end
      end

      it "returns a response" do
        expect(@scorecard).to_not be_nil
      end

      it "returns an array of scorecards" do
        expect(@scorecard).to be_an_instance_of(Array)
      end

      it "returns details of the scorecards" do
        expect(@scorecard.first).to have_key(:interview)
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [1, {created_at: time, updated_at: time, interviewed_at: time, submitted_at: time}] }
        let(:get_from_harvest_api) {double(get_from_harvest_api)}

        before(:each) do
          allow(@client).to(receive(:get_from_harvest_api)).with("/scorecards/1", {created_at: time, updated_at: time, interviewed_at: time, submitted_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_from_harvest_api).with("/scorecards/1", {created_at: time.iso8601, updated_at: time.iso8601, interviewed_at: time.iso8601, submitted_at: time.iso8601})
          @client.all_scorecards(*method_args)
        end
      end
    end

    describe "#scheduled_interviews" do
      context 'given an id' do
        before do
          VCR.use_cassette('client/scheduled_interview') do
            @scheduled_interview = @client.scheduled_interviews(id: 1)
          end
        end

        it "returns a response" do
          expect(@scheduled_interview).to_not be_nil
        end

        it "returns a ScheduledInterview instance" do
          expect(@scheduled_interview).to be_an_instance_of(GreenhouseIo::ScheduledInterview)
        end

        it "returns details of the interview" do
          expect(@scheduled_interview).to have_key(:starts_at)
        end
      end

      context 'given an application_id' do
        let(:fake_api_token) { ENV['GREENHOUSE_API_TOKEN'] }

        before do
          VCR.use_cassette('client/application_scheduled_interviews') do
            @application_scheduled_interviews = @client.scheduled_interviews(
              application_id: 165646508002,
              dehydrate_after_iteration: false
            )
            @application_scheduled_interviews.count # cause lazy paginator to execute its query(s)
          end
        end

        it "returns a response" do
          expect(@application_scheduled_interviews).to_not be_empty
        end

        it "returns ScheduledInterview instances" do
          expect(@application_scheduled_interviews.first).to be_an_instance_of(GreenhouseIo::ScheduledInterview)
        end

        it "returns details of the interviews" do
          expect(@application_scheduled_interviews.first).to have_key(:start)
        end
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [{updated_after: time}] }
        let(:get_resource) {double(get_resource)}
        subject(:interviews) { @client.scheduled_interviews(*method_args) }

        before(:each) do
          allow(@client).to(receive(:get_resource)).with(GreenhouseIo::ScheduledInterviewCollection, {updated_after: time}, {})
        end

        it 'returns a response' do
          expect(@client).to receive(:get_resource).with(GreenhouseIo::ScheduledInterviewCollection, {updated_after: time.iso8601}, {})
          @client.scheduled_interviews(*method_args)

        end
      end
    end

    describe "#jobs", vcr: { cassette_name: 'client/jobs' } do
      let(:method_args) { [] }

      subject(:jobs) { @client.jobs(*method_args) }

      context "given an empty hash" do
        it "returns a response" do
          expect(jobs).to_not be_nil
        end

        it "returns a JobCollection instance" do
          expect(jobs).to be_an_instance_of(GreenhouseIo::JobCollection)
        end

        it "returns jobs details" do
          expect(jobs.first).to have_key(:employment_type)
        end
      end

      context 'given a hash with parameters', :vcr do
        let(:fake_api_token) { ENV['GREENHOUSE_API_TOKEN'] }
        let(:per_page) { 1 } # Use per_page: 1 to limit data size + test pagination
        let(:method_args) { [{ per_page: per_page }] } # This job is fake ("Space Explorer").
        it 'returns a response' do
          expect(jobs).to_not be_nil
        end
        it 'returns a JobCollection instance' do
          expect(jobs).to be_an_instance_of(GreenhouseIo::JobCollection)
        end
        it 'returns job details' do
          expect(jobs.first).to respond_to(:status)
        end
        it 'iterates by utilizing pagination' do
          expect(jobs.first(per_page * 2).map(&:id)).to eq([4237829002, 4298418002])
        end
        context do
          before(:each) do
            allow(GreenhouseIo::Client).to receive(:get).and_return(double('success?': false, headers: {}, code: code))
          end
          context 'when 5xx encountered' do
            let(:code) { 500 }
            it 'retries' do
              expect(@client).to(receive(:get_response)).thrice.and_call_original
              suppress(GreenhouseIo::Error) { jobs.first }
            end
          end
        end
      end

      context "given hash with an id", vcr: { cassette_name: 'client/job' } do
        let(:method_args) { [{ id: 4690 }] }

        subject(:job) { jobs }

        it "returns a response" do
          expect(job).to_not be_nil
        end

        it "returns a Job instance" do
          expect(job).to be_an_instance_of(GreenhouseIo::Job)
        end

        it "returns a job's details" do
          expect(job).to have_key(:employment_type)
        end
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [{created_at: time, updated_at: time, opened_at: time, closed_at: time}] }
        let(:get_resource) {double(get_resource)}

        before(:each) do
          allow(@client).to(receive(:get_resource)).with(GreenhouseIo::JobCollection, {created_at: time, updated_at: time, opened_at: time, closed_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_resource).with(GreenhouseIo::JobCollection, {created_at: time.iso8601, updated_at: time.iso8601, opened_at: time.iso8601, closed_at: time.iso8601}, {})
          @client.jobs(*method_args)
        end
      end
    end

    describe "#stages" do
      before do
        VCR.use_cassette('client/stages') do
          @stages = @client.stages(4690)
        end
      end

      it "returns a response" do
        expect(@stages).to_not be_nil
      end

      it "returns an array of scheduled interviews" do
        expect(@stages).to be_an_instance_of(Array)
      end

      it "returns details of the interview" do
        expect(@stages.first).to have_key(:name)
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [1, {created_at: time, updated_at: time}] }
        let(:get_from_harvest_api) {double(get_from_harvest_api)}

        before(:each) do
          allow(@client).to(receive(:get_from_harvest_api)).with("/jobs/1/stages", {created_at: time, updated_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_from_harvest_api).with("/jobs/1/stages", {created_at: time.iso8601, updated_at: time.iso8601})
          @client.stages(*method_args)
        end
      end
    end

    describe "#job_stages" do
      let(:fake_api_token) { ENV['GREENHOUSE_API_TOKEN'] }

      context 'given an id' do
        before do
          VCR.use_cassette('client/job_stages') do
            @job_stage = @client.job_stages(id: 8404059002)
          end
        end

        it "returns a response" do
          expect(@job_stage).to_not be_nil
        end

        it "returns a JobStage instance" do
          expect(@job_stage).to be_an_instance_of(GreenhouseIo::JobStage)
        end

        it "returns details of the job_stage" do
          expect(@job_stage).to have_key(:name)
        end
      end

      context 'given a job_id' do
        before do
          VCR.use_cassette('client/job_job_stages') do
            @job_job_stages = @client.job_stages(
              job_id: 4576745002,
              dehydrate_after_iteration: false
            )
            @job_job_stages.count # cause lazy paginator to execute its query(s)
          end
        end

        it "returns a response" do
          expect(@job_job_stages).to_not be_empty
        end

        it "returns JobStage instances" do
          expect(@job_job_stages.first).to be_an_instance_of(GreenhouseIo::JobStage)
        end

        it "returns details of the job stages" do
          expect(@job_job_stages.first).to have_key(:name)
        end
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [{updated_after: time}] }
        let(:get_resource) {double(get_resource)}
        subject(:interviews) { @client.job_stages(*method_args) }

        before(:each) do
          allow(@client).to(receive(:get_resource)).with(GreenhouseIo::JobStageCollection, {updated_after: time}, {})
        end

        it 'returns a response' do
          expect(@client).to receive(:get_resource).with(GreenhouseIo::JobStageCollection, {updated_after: time.iso8601}, {})
          @client.job_stages(*method_args)
        end
      end
    end

    describe "#users" do
      context "given an empty hash", vcr: { cassette_name: 'client/users' } do
        before do
          @users = @client.users
        end

        it "returns a response" do
          expect(@users).to_not be_nil
        end

        it "returns a UserCollection instance" do
          expect(@users).to be_an_instance_of(GreenhouseIo::UserCollection)
        end

        it "returns user details" do
          expect(@users.first).to have_key(:name)
        end
      end

      context "given a hash with an id", vcr: { cassette_name: 'client/user' } do
        before do
          @user = @client.users(id: 10327)
        end

        it "returns a response" do
          expect(@user).to_not be_nil
        end

        it "returns a User instance" do
          expect(@user).to be_an_instance_of(GreenhouseIo::User)
        end

        it "returns an user's details" do
          expect(@user).to have_key(:name)
        end
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [{created_at: time, updated_at: time}] }
        let(:get_resource) {double(get_resource)}

        before(:each) do
          allow(@client).to(receive(:get_resource)).with(GreenhouseIo::UserCollection, {created_at: time, updated_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_resource).with(GreenhouseIo::UserCollection, {created_at: time.iso8601, updated_at: time.iso8601}, {})
          @client.users(*method_args)
        end
      end
    end

    describe "#sources" do
      context "given no id" do
        before do
          VCR.use_cassette('client/sources') do
            @sources = @client.sources
          end
        end

        it "returns a response" do
          expect(@sources).to_not be_nil
        end

        it "returns an array of applications" do
          expect(@sources).to be_an_instance_of(Array)
        end

        it "returns application details" do
          expect(@sources.first).to have_key(:name)
        end
      end

      context "given an id" do
        before do
          VCR.use_cassette('client/source') do
            @source = @client.sources(1)
          end
        end

        it "returns a response" do
          expect(@source).to_not be_nil
        end

        it "returns an application hash" do
          expect(@source).to be_an_instance_of(Hash)
        end

        it "returns an application's details" do
          expect(@source).to have_key(:name)
        end
      end
    end

    describe "#offers" do
      context "given no id" do
        before do
          VCR.use_cassette('client/offers') do
            @offers = @client.offers
          end
        end

        it "returns a response" do
          expect(@offers).to_not be nil
        end

        it "returns an array of offers" do
          expect(@offers).to be_an_instance_of(Array)
          expect(@offers.first[:id]).to be_a(Integer).and be > 0
          expect(@offers.first[:created_at]).to be_a(String)
          expect(@offers.first[:version]).to be_a(Integer).and be > 0
          expect(@offers.first[:status]).to be_a(String)
        end
      end

      context "given an id" do
        before do
          VCR.use_cassette('client/offer') do
            @offer = @client.offers(221598)
          end
        end

        it "returns a response" do
          expect(@offer).to_not be nil
        end

        it "returns an offer object" do
          expect(@offer).to be_an_instance_of(Hash)
          expect(@offer[:id]).to be_a(Integer).and be > 0
          expect(@offer[:created_at]).to be_a(String)
          expect(@offer[:version]).to be_a(Integer).and be > 0
          expect(@offer[:status]).to be_a(String)
        end
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [1, {created_at: time, updated_at: time, sent_at: time, starts_at: time}] }
        let(:get_from_harvest_api) {double(get_from_harvest_api)}

        before(:each) do
          allow(@client).to(receive(:get_from_harvest_api)).with("/offers/1", {created_at: time, updated_at: time, sent_at: time, starts_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_from_harvest_api).with("/offers/1", {created_at: time.iso8601, updated_at: time.iso8601, sent_at: time.iso8601, starts_at: time.iso8601})
          @client.offers(*method_args)
        end
      end
    end

    describe "#offers_for_application" do
      before do
        VCR.use_cassette('client/offers_for_application') do
          @offers = @client.offers_for_application(123)
        end
      end

      it "returns a response" do
        expect(@offers).to_not be_nil
      end

      it "returns an array of offers" do
        expect(@offers).to be_an_instance_of(Array)

        return unless @offers.size > 0
        expect(@offers.first).to have_key(:application_id)
        expect(@offers.first).to have_key(:version)
        expect(@offers.first).to have_key(:status)
      end

      context 'passes timestamp parameters' do
        let(:time) { Time.now }
        let(:method_args) { [1, {created_at: time, updated_at: time, sent_at: time, starts_at: time}] }
        let(:get_from_harvest_api) {double(get_from_harvest_api)}

        before(:each) do
          allow(@client).to(receive(:get_from_harvest_api)).with("/applications/1/offers", {created_at: time, updated_at: time, sent_at: time, starts_at: time})
        end

        it 'converts times to iso8601' do
          expect(@client).to receive(:get_from_harvest_api).with("/applications/1/offers", {created_at: time.iso8601, updated_at: time.iso8601, sent_at: time.iso8601, starts_at: time.iso8601})
          @client.offers_for_application(*method_args)
        end
      end
    end

    describe "#current_offer_for_application" do
      before do
        VCR.use_cassette('client/current_offer_for_application') do
          @offer = @client.current_offer_for_application(123)
        end
      end

      it "returns a response" do
        expect(@offer).to_not be_nil
      end

      it "returns an offer object" do
        expect(@offer).to be_an_instance_of(Hash)
        expect(@offer[:id]).to be_a(Integer).and be > 0
        expect(@offer[:created_at]).to be_a(String)
        expect(@offer[:version]).to be_a(Integer).and be > 0
        expect(@offer[:status]).to be_a(String)
      end
    end
  end
end
