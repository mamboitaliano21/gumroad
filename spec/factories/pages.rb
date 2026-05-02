# frozen_string_literal: true

FactoryBot.define do
  factory :page do
    association :seller, factory: :user
    sequence(:title) { |n| "Page #{n}" }
    content_html_raw { "<section><h1>Hello</h1></section>" }
    content_html_sanitized { "<section><h1>Hello</h1></section>" }
    published { true }

    trait :unpublished do
      published { false }
    end

    trait :gumroad_layout do
      settings_json { { "layout" => "gumroad" } }
    end
  end

  factory :page_product do
    association :page
    association :product, factory: :product
    position { 0 }
  end
end
