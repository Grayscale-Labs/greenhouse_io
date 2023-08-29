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
      expect(first.url).to be_nil
      expect(first.length).to eq(100)
      expect(first.first).to be_instance_of(GreenhouseIo::Candidate)

      expect(last.url).to match(/page=3&per_page=100/)
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

  it 'blanks out records when .each is used' do
    all = candidates.each.to_a
    expect(all[0]).to be_a(GreenhouseIo::Candidate)
    expect(candidates.count {|i| i == :dehydrated }).to eq candidates.count
  end

  it 'blanks out pages when .each is called' do
    all = candidates.each_page.to_a
    expect(all[0][0]).to be_a(GreenhouseIo::Candidate)
    all[0].each {}
    expect(all[0][0]).to eq :dehydrated
  end
end
