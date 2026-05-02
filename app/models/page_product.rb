# frozen_string_literal: true

class PageProduct < ApplicationRecord
  belongs_to :page
  belongs_to :product, class_name: "Link", foreign_key: "product_id"

  validates :page_id, presence: true
  validates :product_id, presence: true, uniqueness: { scope: :page_id }
end
