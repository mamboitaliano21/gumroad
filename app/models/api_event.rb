# frozen_string_literal: true

class ApiEvent < ApplicationRecord
  belongs_to :user
  belongs_to :oauth_application, optional: true

  validates :event_type, :source, :controller_action, presence: true

  SOURCES = %w[cli api mobile].freeze
  validates :source, inclusion: { in: SOURCES }

  scope :from_cli, -> { where(source: "cli") }
  scope :from_api, -> { where(source: "api") }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }

  # Determine source from User-Agent header
  def self.detect_source(user_agent)
    return "cli" if user_agent&.match?(/gumroad-cli/i)
    return "mobile" if user_agent&.match?(/GumroadMobile|Gumroad iOS|Gumroad Android/i)

    "api"
  end
end
