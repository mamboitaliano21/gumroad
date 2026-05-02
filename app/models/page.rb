# frozen_string_literal: true

class Page < ApplicationRecord
  include Deletable, ExternalId

  SLUG_FORMAT = /\A[a-z0-9]{8}\z/
  SLUG_MAX_RETRIES = 10
  TITLE_MAX_LENGTH = 200
  CONTENT_MAX_BYTES = 1.megabyte

  DEFAULT_SETTINGS = { "layout" => "chromeless" }.freeze

  belongs_to :seller, class_name: "User"
  has_many :page_products, dependent: :destroy
  has_many :products, through: :page_products

  before_validation :set_slug
  before_save :ensure_settings_json

  validates :slug, presence: true,
                   format: { with: SLUG_FORMAT },
                   uniqueness: { case_sensitive: false }
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validate :content_within_size_limit

  attribute :settings_json, default: -> { DEFAULT_SETTINGS.dup }

  def self.generate_slug(max_retries: SLUG_MAX_RETRIES)
    retries = 0
    candidate = SecureRandom.alphanumeric(8).downcase

    while exists?(slug: candidate)
      retries += 1
      raise "Failed to generate unique slug after #{max_retries} attempts" if retries >= max_retries
      candidate = SecureRandom.alphanumeric(8).downcase
    end

    candidate
  end

  def chromeless?
    settings_json.is_a?(Hash) && settings_json["layout"] != "gumroad"
  end

  private
    def set_slug
      return if slug.present?
      self.slug = self.class.generate_slug
    end

    def ensure_settings_json
      self.settings_json = DEFAULT_SETTINGS.dup if settings_json.blank?
    end

    def content_within_size_limit
      raw = content_html_raw.to_s
      return if raw.bytesize <= CONTENT_MAX_BYTES
      errors.add(:content_html_raw, "must be at most #{CONTENT_MAX_BYTES} bytes")
    end
end
