# frozen_string_literal: true

class ContentModeration::ImageEncoder
  MAX_DIMENSION = 512
  FETCH_TIMEOUT = 5
  QUALITY = 75

  # Fetches an image URL, downscales to MAX_DIMENSION, and returns a base64 data URI.
  # Returns nil if the image can't be fetched or processed.
  def self.to_base64_data_uri(url)
    response = fetch_image(url)
    return nil unless response

    image = MiniMagick::Image.read(response.body)
    image.resize "#{MAX_DIMENSION}x#{MAX_DIMENSION}>"
    image.quality QUALITY.to_s
    image.format "jpeg"

    base64 = Base64.strict_encode64(image.to_blob)
    "data:image/jpeg;base64,#{base64}"
  rescue StandardError => e
    Rails.logger.warn("ContentModeration::ImageEncoder failed for #{url}: #{e.message}")
    nil
  end

  def self.fetch_image(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = FETCH_TIMEOUT
    http.read_timeout = FETCH_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    response.is_a?(Net::HTTPSuccess) ? response : nil
  rescue StandardError => e
    Rails.logger.warn("ContentModeration::ImageEncoder fetch failed for #{url}: #{e.message}")
    nil
  end
end
