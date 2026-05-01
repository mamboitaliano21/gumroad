# frozen_string_literal: true

class LandingPage < ApplicationRecord
  include Deletable
  include ExternalId
  include ActionView::Helpers::SanitizeHelper

  PER_PRODUCT_LIMIT = 50
  SLUG_FORMAT = /\A[a-z0-9]{8}\z/

  belongs_to :product, class_name: "Link", foreign_key: "product_id"

  before_validation :set_slug

  validates :slug,
            presence: true,
            format: { with: SLUG_FORMAT },
            uniqueness: { case_sensitive: false }
  validate :landing_page_count_within_limit, on: :create

  def self.generate_slug(max_retries: 10)
    retries = 0
    candidate = SecureRandom.alphanumeric(8).downcase

    while exists?(slug: candidate)
      retries += 1
      raise "Failed to generate unique slug after #{max_retries} attempts" if retries >= max_retries

      candidate = SecureRandom.alphanumeric(8).downcase
    end

    candidate
  end

  def html_safe_description
    return unless description.present?

    Rinku.auto_link(sanitize(description, scrubber: description_scrubber), :all, 'target="_blank" rel="noopener noreferrer nofollow"').html_safe
  end

  def url
    "#{product.long_url}?lp=#{slug}"
  end

  def as_json(_options = {})
    {
      id: external_id,
      slug:,
      url:,
      product_id: product.external_id,
      product_permalink: product.unique_permalink,
      name:,
      description:,
      custom_summary:,
      custom_attributes:,
      position:,
      created_at:,
      updated_at:,
    }
  end

  private
    def set_slug
      self.slug = self.class.generate_slug if slug.blank?
    end

    def landing_page_count_within_limit
      return if product_id.blank?
      count = self.class.alive.where(product_id:).where.not(id:).count
      errors.add(:base, "Cannot create more than #{PER_PRODUCT_LIMIT} landing pages per product") if count >= PER_PRODUCT_LIMIT
    end

    def description_scrubber
      unless Loofah::HTML5::SafeList::ACCEPTABLE_CSS_PROPERTIES.include?("position")
        Loofah::HTML5::SafeList::ACCEPTABLE_CSS_PROPERTIES.add("position")
      end

      Loofah::Scrubber.new do |node|
        if %w[strong b em u s h1 h2 h3 h4 h5 h6 pre code ul ol li hr blockquote p a figure figcaption img div span iframe script br upsell-card public-file-embed review-card].exclude?(node.name) && !node.text?
          node.remove
        elsif node.name == "iframe"
          if node["src"].present? && (URI.parse(node["src"]) rescue nil)&.host == "cdn.iframe.ly"
            node.attributes.each do |attr|
              node.remove_attribute(attr.first) unless %w[src frameborder allowfullscreen scrolling allow style].include?(attr.first)
            end
          else
            node.remove
          end
        elsif node.name == "script" && !(
          node["src"].present? &&
            (URI.parse(node["src"]) rescue nil)&.host == "cdn.iframe.ly" &&
            (URI.parse(node["src"]) rescue nil)&.path == "/embed.js"
        )
          node.remove
        elsif node.name == "upsell-card"
          node.attributes.each do |attr|
            node.remove_attribute(attr.first) unless %w[id productid variantid discount].include?(attr.first)
          end
        elsif node.name == "review-card"
          node.attributes.each do |attr|
            node.remove_attribute(attr.first) unless %w[reviewid].include?(attr.first)
          end
          begin
            review_data = node["reviewid"]
            unless product.product_reviews.find_by_external_id(review_data)
              node.remove
            end
          end
        else
          Loofah::HTML5::Scrub.scrub_attributes(node)
        end
        if %w[iframe script img].include?(node.name) && node["src"]&.start_with?("//")
          node.attribute("src").value = "#{PROTOCOL}:#{node["src"]}"
        end
      end
    end
end
