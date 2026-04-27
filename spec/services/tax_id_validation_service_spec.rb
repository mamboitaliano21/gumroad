# frozen_string_literal: true

require "spec_helper"

describe TaxIdValidationService, :vcr do
  let(:tax_id) { "528491" }
  let(:country_code) { "IS" }

  it "returns true when a valid tax id is provided" do
    expect(described_class.new(tax_id, country_code).process).to be(true)
  end

  it "returns false when the tax id is nil" do
    expect(described_class.new(nil, country_code).process).to be(false)
  end

  it "returns false when the tax id is empty" do
    expect(described_class.new("", country_code).process).to be(false)
  end

  it "returns false when the country code is nil" do
    expect(described_class.new(tax_id, nil).process).to be(false)
  end

  it "returns false when the country code is empty" do
    expect(described_class.new(tax_id, "").process).to be(false)
  end

  it "returns false when the tax id is not valid" do
    expect(described_class.new("1234567890", country_code).process).to be(false)
  end

  context "when the API is unreachable" do
    before do
      allow_any_instance_of(described_class).to receive(:sleep)
    end

    it "retries and returns false when the API request times out on every attempt" do
      expect(HTTParty).to receive(:get).exactly(TaxIdValidationService::MAX_TRIES).times.and_raise(Net::OpenTimeout)
      expect(described_class.new(tax_id, country_code).process).to be(false)
    end

    it "retries and returns false when the API connection is refused on every attempt" do
      expect(HTTParty).to receive(:get).exactly(TaxIdValidationService::MAX_TRIES).times.and_raise(Errno::ECONNREFUSED)
      expect(described_class.new(tax_id, country_code).process).to be(false)
    end

    it "returns the API result if a retry succeeds after a transient network error" do
      response = instance_double(HTTParty::Response, code: 200, parsed_response: { "is_valid" => true })
      call_count = 0
      allow(HTTParty).to receive(:get) do
        call_count += 1
        raise Net::OpenTimeout if call_count == 1
        response
      end
      expect(described_class.new(tax_id, country_code).process).to be(true)
      expect(call_count).to eq(2)
    end
  end
end
