# frozen_string_literal: true

require "spec_helper"

describe("Product page landing page override (?lp=)", js: true, type: :system) do
  before do
    @product = create(:product, name: "Original product", description: "<p>Original description</p>")
    @product.save_custom_summary("Original summary")
    @product.save_custom_attributes([{ "name" => "Format", "value" => "PDF" }])
    @product.reload
  end

  it "applies the landing page overrides to the rendered product page" do
    landing_page = create(:landing_page,
                          product: @product,
                          slug: "abcdefgh",
                          name: "Override headline",
                          description: "<p>Override copy</p>",
                          custom_summary: "Override summary",
                          custom_attributes: [{ "name" => "Audience", "value" => "Engineers" }])

    visit landing_page.url

    expect(page).to have_text("Override headline")
    expect(page).to have_text("Override copy")
    expect(page).to have_text("Override summary")
    expect(page).to have_text("Audience")
    expect(page).to have_text("Engineers")
    expect(page).to_not have_text("Original product")
  end

  it "renders the canonical product page when ?lp= is absent" do
    create(:landing_page, product: @product, slug: "abcdefgh", name: "Should not appear")

    visit @product.long_url

    expect(page).to have_text("Original product")
    expect(page).to have_text("Original description")
    expect(page).to_not have_text("Should not appear")
  end

  it "renders product defaults for fields the landing page does not override" do
    landing_page = create(:landing_page, product: @product, slug: "abcdefgh", name: "Override headline")

    visit landing_page.url

    expect(page).to have_text("Override headline")
    expect(page).to have_text("Original description")
    expect(page).to have_text("Original summary")
  end
end
