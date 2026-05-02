# frozen_string_literal: true

require "spec_helper"

describe PageProduct do
  describe "associations" do
    it { is_expected.to belong_to(:page) }
    it { is_expected.to belong_to(:product).class_name("Link") }
  end

  describe "validations" do
    it "enforces uniqueness on [page_id, product_id]" do
      page = create(:page)
      product = create(:product)
      create(:page_product, page:, product:)
      duplicate = build(:page_product, page:, product:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_id]).to be_present
    end

    it "allows the same product on different pages" do
      product = create(:product)
      page_a = create(:page)
      page_b = create(:page)
      create(:page_product, page: page_a, product:)
      expect(build(:page_product, page: page_b, product:)).to be_valid
    end
  end
end
