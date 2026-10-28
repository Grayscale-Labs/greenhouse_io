# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GreenhouseIo::V3::TokenEndpoint do
  subject(:endpoint) { described_class.new(client_id: 'cid', client_secret: 'secret') }

  let(:token_url) { 'https://auth.greenhouse.io/token' }
  let(:expires_at) { (Time.now + 3600).iso8601 }

  def stub_token(body:, status: 200, headers: {})
    stub_request(:post, token_url).to_return(
      status: status,
      body: body.is_a?(String) ? body : body.to_json,
      headers: { 'Content-Type' => 'application/json' }.merge(headers)
    )
  end

  describe '#exchange_refresh_token' do
    it 'returns the pair' do
      stub_token(body: { token_type: 'Bearer', access_token: 'at', refresh_token: 'rt', expires_at: expires_at })

      pair = endpoint.exchange_refresh_token('old_rt')

      expect(pair.access_token).to eq('at')
      expect(pair.refresh_token).to eq('rt')
      expect(pair.expires_at).to eq(expires_at)
      expect(pair.token_type).to eq('Bearer')
    end

    it 'sends the grant and basic auth' do
      stub_token(body: { access_token: 'at' })

      endpoint.exchange_refresh_token('old_rt')

      expect(WebMock).to have_requested(:post, token_url)
        .with(body: { 'grant_type' => 'refresh_token', 'refresh_token' => 'old_rt' },
              headers: { 'Authorization' => "Basic #{Base64.strict_encode64('cid:secret')}" })
    end

    it 'passes expires_at through unparsed' do
      stub_token(body: { access_token: 'at', expires_at: '1760534265' })

      expect(endpoint.exchange_refresh_token('old_rt').expires_at).to eq('1760534265')
    end

    # The consumer decides what a failure means; a 429 is not a reauthorization.
    it 'raises GreenhouseIo::Error with the status and headers' do
      stub_token(status: 429, body: 'slow down', headers: { 'X-RateLimit-Remaining' => '0' })

      expect { endpoint.exchange_refresh_token('old_rt') }.to raise_error(GreenhouseIo::Error) do |error|
        expect(error).not_to be_a(GreenhouseIo::ReauthorizationRequired)
        expect(error.code).to eq(429)
        expect(error.headers['x-ratelimit-remaining']).to eq('0')
      end
    end

    it 'raises on invalid_grant without deciding it is terminal' do
      stub_token(status: 400, body: { error: 'invalid_grant' })

      expect { endpoint.exchange_refresh_token('dead_rt') }
        .to raise_error(GreenhouseIo::Error) { |e| expect(e.code).to eq(400) }
    end
  end

  describe '#exchange_authorization_code' do
    it 'sends the code without a redirect_uri' do
      stub_token(body: { access_token: 'at', refresh_token: 'rt' })

      expect(endpoint.exchange_authorization_code('the_code').refresh_token).to eq('rt')
      expect(WebMock).to have_requested(:post, token_url)
        .with(body: { 'grant_type' => 'authorization_code', 'code' => 'the_code' })
    end
  end

  describe '#fetch_client_credentials' do
    it 'sends the sub' do
      stub_token(body: { access_token: 'at' })

      endpoint.fetch_client_credentials(sub: '5414812002')

      expect(WebMock).to have_requested(:post, token_url)
        .with(body: { 'grant_type' => 'client_credentials', 'sub' => '5414812002' })
    end
  end

  describe 'timeouts' do
    it 'defaults to DEFAULT_TIMEOUT' do
      expect(HTTParty).to receive(:post)
        .with(token_url, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
        .and_return(instance_double(HTTParty::Response, success?: true, body: '{}'))

      endpoint.request('grant_type' => 'refresh_token')
    end

    it 'honors an override' do
      expect(HTTParty).to receive(:post)
        .with(token_url, hash_including(timeout: 2))
        .and_return(instance_double(HTTParty::Response, success?: true, body: '{}'))

      described_class.new(client_id: 'cid', client_secret: 'secret', timeout: 2)
                     .request('grant_type' => 'refresh_token')
    end

    it 'surfaces a read timeout' do
      stub_request(:post, token_url).to_timeout

      expect { endpoint.exchange_refresh_token('old_rt') }.to raise_error(Net::OpenTimeout)
    end
  end

  it 'persists nothing' do
    stub_token(body: { access_token: 'at', refresh_token: 'rt' })

    expect(endpoint.exchange_refresh_token('old_rt')).to be_a(GreenhouseIo::V3::TokenPair)
    expect(endpoint.instance_variables).to contain_exactly(:@client_id, :@client_secret, :@timeout)
  end
end
