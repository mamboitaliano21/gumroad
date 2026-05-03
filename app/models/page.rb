# frozen_string_literal: true

class Page < ApplicationRecord
  include Deletable

  TITLE_MAX_LENGTH = 255
  CONTENT_MAX_BYTES = 1.megabyte
  PERMALINK_LENGTH = 8
  PERMALINK_FORMAT = /\A[a-z0-9]{#{PERMALINK_LENGTH}}\z/

  belongs_to :seller, class_name: "User"

  validates :unique_permalink, presence: true, uniqueness: true, format: { with: PERMALINK_FORMAT }
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :raw_html, presence: true
  validate :raw_html_within_size_limit

  before_validation :set_unique_permalink
  before_validation :resanitize

  def published?
    alive? && unpublished_at.nil?
  end

  def self.generate_unique_permalink(max_retries: 10)
    retries = 0
    candidate = SecureRandom.alphanumeric(PERMALINK_LENGTH).downcase

    while exists?(unique_permalink: candidate)
      retries += 1
      raise "Failed to generate unique permalink after #{max_retries} attempts" if retries >= max_retries

      candidate = SecureRandom.alphanumeric(PERMALINK_LENGTH).downcase
    end

    candidate
  end

  private
    def set_unique_permalink
      self.unique_permalink ||= self.class.generate_unique_permalink
    end

    def resanitize
      result = Pages::SanitizeHtmlService.new(raw_html.to_s).perform
      self.sanitized_html = result[:html]
    end

    def raw_html_within_size_limit
      return if raw_html.to_s.bytesize <= CONTENT_MAX_BYTES
      errors.add(:raw_html, "exceeds #{CONTENT_MAX_BYTES} bytes")
    end
end
