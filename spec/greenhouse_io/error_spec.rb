require 'spec_helper'

describe GreenhouseIo::Error do

  describe "#inspect" do

    context "when http error code is present" do
      it "creates an error with the code" do
        http_error = GreenhouseIo::Error.new(nil, 404)
        expect(http_error.code).to eq(404)
      end
    end

    context "when its an internal gem error" do
      it "creates an error with a message" do
        gem_error = GreenhouseIo::Error.new("organization can't be blank", nil)
        expect(gem_error.message).to eq("organization can't be blank")
      end
    end

  end

  describe "#headers" do
    it "defaults to an empty hash" do
      expect(GreenhouseIo::Error.new("boom").headers).to eq({})
      expect(GreenhouseIo::Error.new("boom", 500, headers: nil).headers).to eq({})
    end

    it "downcases keys" do
      error = GreenhouseIo::Error.new("429", nil, headers: { "Retry-After" => "30" })

      expect(error.headers["retry-after"]).to eq("30")
    end

    it "joins a header that arrived more than once" do
      error = GreenhouseIo::Error.new("429", nil, headers: { "set-cookie" => %w[a=1 b=2] })

      expect(error.headers["set-cookie"]).to eq("a=1, b=2")
    end

    it "ignores a value that does not convert to a hash" do
      expect(GreenhouseIo::Error.new("500", nil, headers: "not headers").headers).to eq({})
    end

    it "is preserved when re-raised as ReauthorizationRequired" do
      error = GreenhouseIo::ReauthorizationRequired.new("Retry later", 429, headers: { "Retry-After" => "47" })

      expect(error.code).to eq(429)
      expect(error.headers["retry-after"]).to eq("47")
    end
  end

end
