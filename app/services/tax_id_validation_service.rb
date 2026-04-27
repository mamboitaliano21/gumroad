# frozen_string_literal: true


class TaxIdValidationService
  attr_reader :tax_id, :country_code

  def initialize(tax_id, country_code)
    @tax_id = tax_id
    @country_code = country_code
  end

  def process
    return false if tax_id.blank?
    return false if country_code.blank?

    Rails.cache.fetch("tax_id_validation_#{tax_id}_#{country_code}", expires_in: 10.minutes) do
      valid_tax_id?
    end
  end

  private
    TAX_ID_PRO_ENDPOINT_TEMPLATE = Addressable::Template.new(
      "https://v3.api.taxid.pro/validate?country={country_code}&tin={tax_id}"
    )
    TAX_ID_PRO_HEADERS = {
      "Authorization" => "Bearer #{TAX_ID_PRO_API_KEY}"
    }
    RETRIABLE_NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError].freeze
    MAX_TRIES = 3
    RETRY_DELAY = 1

    def valid_tax_id?
      tries = 0
      begin
        tries += 1
        response = HTTParty.get(TAX_ID_PRO_ENDPOINT_TEMPLATE.expand(country_code:, tax_id:).to_s, headers: TAX_ID_PRO_HEADERS, timeout: 5)
        response.code == 200 && response.parsed_response["is_valid"]
      rescue *RETRIABLE_NETWORK_ERRORS => e
        if tries < MAX_TRIES
          Rails.logger.info("TaxIdValidationService network error, attempt #{tries}/#{MAX_TRIES}: #{e.class}: #{e.message}")
          sleep(RETRY_DELAY)
          retry
        else
          Rails.logger.error("TaxIdValidationService failed after #{MAX_TRIES} attempts: #{e.class}: #{e.message}")
          false
        end
      end
    end
end
