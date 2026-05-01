# frozen_string_literal: true

FactoryBot.define do
  factory :landing_page do
    association :product, factory: :product
    name { "Campaign override" }
  end
end
