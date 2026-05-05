# frozen_string_literal: true

FactoryBot.define do
  factory :page do
    association :seller, factory: :user
    title { "My page" }
    raw_html { "<div class=\"p-4 text-2xl\">Hello</div>" }
  end
end
