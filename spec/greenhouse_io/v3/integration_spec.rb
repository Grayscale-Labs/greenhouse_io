# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "V3 Integration", :vcr do
  let(:client) do
    GreenhouseIo::V3::Client.new(
      client_id: ENV.fetch("GREENHOUSE_V3_CLIENT_ID", "test"),
      client_secret: ENV.fetch("GREENHOUSE_V3_CLIENT_SECRET", "test"),
      sub: ENV.fetch("GREENHOUSE_V3_SUB", "12345")
    )
  end

  describe "jobs endpoint" do
    it "fetches jobs from the v3 API", vcr: { cassette_name: "v3/integration_jobs" } do
      jobs = client.jobs(per_page: 2)
      first_job = jobs.first
      expect(first_job.id).to be_a(Integer)
      expect(first_job.name).to be_a(String)
    end

    it "paginates through all jobs", vcr: { cassette_name: "v3/integration_jobs_paginated" } do
      jobs = client.jobs(per_page: 2)
      all_ids = []
      jobs.each_page do |page|
        page.each { |job| all_ids << job.id }
      end
      expect(all_ids.length).to be > 0
      expect(all_ids.uniq.length).to eq(all_ids.length)
    end
  end

  describe "token refresh" do
    it "recovers from expired token", vcr: { cassette_name: "v3/integration_token_refresh" } do
      client.instance_variable_get(:@token_manager).token_store[:access_token] = "invalid_expired_token"

      jobs = client.jobs(per_page: 1)
      expect(jobs.first.id).to be_a(Integer)
    end
  end
end
