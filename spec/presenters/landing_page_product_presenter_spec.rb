# frozen_string_literal: true

require "spec_helper"

describe LandingPageProductPresenter do
  let(:product) do
    product = create(:product, name: "Original product", description: "<p>Original description</p>")
    product.save_custom_summary("Original summary")
    product.save_custom_attributes([{ "name" => "Format", "value" => "PDF" }])
    product.reload
  end

  let(:base_props) do
    {
      product: {
        name: product.name,
        description_html: product.html_safe_description,
        summary: product.custom_summary,
        attributes: [
          { name: "Format", value: "PDF" },
          { name: "Length", value: "120 pages" },
        ],
      }
    }
  end

  describe ".apply" do
    it "returns the same props when the landing page has no overrides" do
      landing_page = create(:landing_page, product:, name: nil, description: nil, custom_summary: nil, custom_attributes: nil)

      result = described_class.apply(props: base_props, landing_page:)

      expect(result).to eq(base_props)
    end

    it "overrides only the fields the landing page defines" do
      landing_page = create(:landing_page, product:, name: "Override name", description: nil, custom_summary: "Override summary", custom_attributes: nil)

      result = described_class.apply(props: base_props, landing_page:)

      expect(result[:product][:name]).to eq("Override name")
      expect(result[:product][:summary]).to eq("Override summary")
      expect(result[:product][:description_html]).to eq(product.html_safe_description)
      expect(result[:product][:attributes]).to eq(base_props[:product][:attributes])
    end

    it "overrides description with landing page sanitized HTML" do
      landing_page = create(:landing_page, product:, description: "<p>Override <strong>copy</strong></p>")

      result = described_class.apply(props: base_props, landing_page:)

      expect(result[:product][:description_html]).to include("<p>Override <strong>copy</strong></p>")
      expect(result[:product][:description_html]).not_to include(product.description)
    end

    it "replaces only the custom-attribute portion and preserves file-info attributes" do
      landing_page = create(:landing_page, product:, custom_attributes: [{ "name" => "Audience", "value" => "Senior engineers" }])

      result = described_class.apply(props: base_props, landing_page:)

      expect(result[:product][:attributes]).to eq([
                                                    { name: "Audience", value: "Senior engineers" },
                                                    { name: "Length", value: "120 pages" },
                                                  ])
    end

    it "drops empty custom_attribute entries" do
      landing_page = create(:landing_page, product:, custom_attributes: [{ "name" => "Audience", "value" => "Engineers" }, { "name" => "", "value" => "" }])

      result = described_class.apply(props: base_props, landing_page:)

      expect(result[:product][:attributes]).to eq([
                                                    { name: "Audience", value: "Engineers" },
                                                    { name: "Length", value: "120 pages" },
                                                  ])
    end

    it "does not mutate the input props" do
      landing_page = create(:landing_page, product:, name: "Override name")
      original_name = base_props[:product][:name]

      described_class.apply(props: base_props, landing_page:)

      expect(base_props[:product][:name]).to eq(original_name)
    end
  end
end
