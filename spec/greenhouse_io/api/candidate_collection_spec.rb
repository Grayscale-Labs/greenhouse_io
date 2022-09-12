require 'spec_helper'

require 'greenhouse_io/api/candidate_collection'

RSpec.describe GreenhouseIo::CandidateCollection do
  let(:client) { GreenhouseIo::Client.new('123FakeToken') }
  subject(:candidates) { client.candidates }

  around { |spec| VCR.use_cassette('candidates') { spec.call } }

  it 'allows iterating results by page' do
    pages = candidates.each_page.to_a
    first  = pages.first
    last   = pages.last

    aggregate_failures do
      expect(first.next_page_url).to match(/page=2&per_page=100/)
      expect(first.length).to eq(100)
      expect(first.first).to be_instance_of(GreenhouseIo::Candidate)

      expect(last.next_page_url).to be_nil
      expect(last.length).to eq(18)
    end
  end

  it 'allows iterating multiple times' do
    pages = candidates.each_page.to_a
    pages2 = candidates.each_page.to_a

    expect(pages2).to eq(pages)
  end

  it 'allows mixing each/each_page' do
    all = candidates.each.to_a
    pages = candidates.each_page.to_a

    expect(pages.length).to eq(3)
    expect(all.length).to eq(pages.map(&:count).sum)
  end
end
