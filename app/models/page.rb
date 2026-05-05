# frozen_string_literal: true

class Page < ApplicationRecord
  include Deletable

  TITLE_MAX_LENGTH = 255
  MAX_RAW_HTML_BYTES = 512.kilobytes

  belongs_to :seller, class_name: "User"

  validates :permalink, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :raw_html, presence: true
  validate :raw_html_within_size_limit

  before_validation :set_permalink
  before_save :sanitize_and_compile, if: :raw_html_changed?

  def self.generate_unique_permalink(max_retries: 10)
    retries = 0
    candidate = SecureRandom.alphanumeric(8).downcase

    while exists?(permalink: candidate)
      retries += 1
      raise "Failed to generate unique permalink after #{max_retries} attempts" if retries >= max_retries

      candidate = SecureRandom.alphanumeric(8).downcase
    end

    candidate
  end

  private
    def set_permalink
      self.permalink ||= self.class.generate_unique_permalink
    end

    def sanitize_and_compile
      sanitize_result = Pages::SanitizeHtmlService.new(raw_html.to_s).perform
      self.sanitized_html = sanitize_result[:html]
      self.compiled_css = Pages::CompileTailwindService.new(self.sanitized_html).perform
    end

    def raw_html_within_size_limit
      return if raw_html.to_s.bytesize <= MAX_RAW_HTML_BYTES
      errors.add(:raw_html, "exceeds #{MAX_RAW_HTML_BYTES} bytes")
    end
end
