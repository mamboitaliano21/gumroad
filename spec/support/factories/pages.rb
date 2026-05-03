# frozen_string_literal: true

FactoryBot.define do
  factory :page do
    association :seller, factory: :user
    sequence(:title) { |n| "Page #{n}" }
    raw_html { "<section><h1>Hello</h1></section>" }

    trait :unpublished do
      unpublished_at { Time.current }
    end
  end
end
