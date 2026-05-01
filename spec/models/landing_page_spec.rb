# frozen_string_literal: true

require "spec_helper"

describe LandingPage do
  describe "associations" do
    it { is_expected.to belong_to(:product).class_name("Link") }
  end

  describe "validations" do
    describe "slug" do
      subject(:landing_page) { build(:landing_page, slug: "abcdefgh") }

      it { is_expected.to validate_uniqueness_of(:slug).case_insensitive }
      it { is_expected.to allow_value("abcdefgh").for(:slug) }
      it { is_expected.to allow_value("0123abcd").for(:slug) }
      it { is_expected.not_to allow_value("ABCDEFGH").for(:slug) }
      it { is_expected.not_to allow_value("abcdefg").for(:slug) }
      it { is_expected.not_to allow_value("abcdefghi").for(:slug) }
      it { is_expected.not_to allow_value("abc-defg").for(:slug) }
    end

    describe "landing_page_count_within_limit" do
      let(:product) { create(:product) }

      it "allows creating up to PER_PRODUCT_LIMIT alive landing pages" do
        stub_const("LandingPage::PER_PRODUCT_LIMIT", 3)
        3.times { create(:landing_page, product:) }

        landing_page = build(:landing_page, product:)
        expect(landing_page).not_to be_valid
        expect(landing_page.errors[:base]).to include("Cannot create more than 3 landing pages per product")
      end

      it "does not count soft-deleted landing pages towards the limit" do
        stub_const("LandingPage::PER_PRODUCT_LIMIT", 2)
        create(:landing_page, product:)
        create(:landing_page, product:).mark_deleted!

        landing_page = build(:landing_page, product:)
        expect(landing_page).to be_valid
      end

      it "scopes the count per product" do
        stub_const("LandingPage::PER_PRODUCT_LIMIT", 1)
        create(:landing_page, product:)

        other_product = create(:product)
        landing_page = build(:landing_page, product: other_product)
        expect(landing_page).to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "#set_slug" do
      it "sets a generated slug before validation when blank" do
        landing_page = build(:landing_page, slug: nil)
        landing_page.valid?
        expect(landing_page.slug).to match(LandingPage::SLUG_FORMAT)
      end

      it "does not overwrite a pre-set slug" do
        landing_page = build(:landing_page, slug: "abcdefgh")
        landing_page.valid?
        expect(landing_page.slug).to eq("abcdefgh")
      end
    end
  end

  describe "DB-level uniqueness" do
    it "enforces uniqueness globally across products" do
      product_a = create(:product)
      product_b = create(:product)
      create(:landing_page, product: product_a, slug: "abcdefgh")

      expect do
        landing_page = build(:landing_page, product: product_b, slug: "abcdefgh")
        landing_page.save(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".generate_slug" do
    it "generates an 8-character lowercase alphanumeric slug" do
      slug = described_class.generate_slug
      expect(slug).to match(LandingPage::SLUG_FORMAT)
    end

    it "generates unique slugs" do
      existing = described_class.generate_slug
      create(:landing_page, slug: existing)

      expect(described_class.generate_slug).not_to eq(existing)
    end

    it "retries until finding a unique slug" do
      allow(SecureRandom).to receive(:alphanumeric).and_return("existin1", "existin2", "unique12")
      create(:landing_page, slug: "existin1")
      create(:landing_page, slug: "existin2")

      expect(described_class.generate_slug).to eq("unique12")
      expect(SecureRandom).to have_received(:alphanumeric).exactly(3).times
    end

    it "raises an error after max retries" do
      allow(SecureRandom).to receive(:alphanumeric).and_return("existing")
      create(:landing_page, slug: "existing")

      expect do
        described_class.generate_slug(max_retries: 3)
      end.to raise_error("Failed to generate unique slug after 3 attempts")
      expect(SecureRandom).to have_received(:alphanumeric).exactly(3).times
    end
  end

  describe "#external_id" do
    it "returns a round-trippable external id" do
      landing_page = create(:landing_page)
      expect(LandingPage.find_by_external_id(landing_page.external_id)).to eq(landing_page)
    end
  end

  describe "soft delete" do
    it "is included in the alive scope when alive" do
      landing_page = create(:landing_page)
      expect(LandingPage.alive).to include(landing_page)
    end

    it "is excluded from the alive scope when deleted" do
      landing_page = create(:landing_page)
      landing_page.mark_deleted!
      expect(LandingPage.alive).not_to include(landing_page)
    end
  end

  describe "#html_safe_description" do
    let(:landing_page) { create(:landing_page) }

    it "returns nil when description is blank" do
      landing_page.update!(description: "")
      expect(landing_page.html_safe_description).to be_nil
    end

    it "preserves whitelisted markup and auto-links URLs" do
      landing_page.update!(description: "<p>Hello <strong>world</strong> https://example.com</p>")

      expect(landing_page.html_safe_description).to include("<strong>world</strong>")
      expect(landing_page.html_safe_description).to include("https://example.com")
      expect(landing_page.html_safe_description).to include('rel="noopener noreferrer nofollow"')
    end

    it "strips disallowed scripts" do
      landing_page.update!(description: "<p>Safe</p><script>alert(1)</script>")
      expect(landing_page.html_safe_description).not_to include("alert(1)")
      expect(landing_page.html_safe_description).to include("<p>Safe</p>")
    end

    describe "parity with Link#html_safe_description" do
      [
        "<p>plain copy with <strong>bold</strong> and <em>italic</em></p>",
        "<p>auto-link https://example.com works</p>",
        "<p>safe</p><script>alert(1)</script>",
        "<p>safe</p><script src=\"https://cdn.iframe.ly/embed.js\"></script>",
        "<iframe src=\"https://cdn.iframe.ly/abc\" frameborder=\"0\" allowfullscreen></iframe>",
        "<iframe src=\"https://evil.example.com/x\"></iframe>",
        "<upsell-card id=\"1\" productid=\"abc\" variantid=\"v\" discount=\"10\"></upsell-card>",
        "<upsell-card onclick=\"steal()\" productid=\"abc\"></upsell-card>",
        "<public-file-embed id=\"abc\"></public-file-embed>",
        "<img src=\"//cdn.example.com/x.png\" />",
        "<h1>Heading</h1><h2>Sub</h2><blockquote>Quote</blockquote><pre><code>code</code></pre>",
        "<ul><li>one</li><li>two</li></ul><ol><li>a</li></ol>",
        "<div style=\"position: absolute;\">positioned</div>",
        "<custom-element>not allowed</custom-element>",
      ].each do |fixture|
        it "matches Link#html_safe_description for: #{fixture.truncate(40)}" do
          landing_page.update!(description: fixture)
          landing_page.product.update!(description: fixture)

          expect(landing_page.html_safe_description).to eq(landing_page.product.html_safe_description)
        end
      end
    end
  end

  describe "#url" do
    it "returns the product canonical URL with the lp query parameter" do
      landing_page = create(:landing_page, slug: "abcdefgh")
      expect(landing_page.url).to eq("#{landing_page.product.long_url}?lp=abcdefgh")
    end
  end

  describe "#as_json" do
    it "returns the locked JSON shape" do
      landing_page = create(:landing_page, slug: "abcdefgh", name: "Spring sale", description: "<p>Hi</p>", custom_summary: "Summary", custom_attributes: [{ "name" => "Audience", "value" => "Engineers" }])
      json = landing_page.as_json

      expect(json[:id]).to eq(landing_page.external_id)
      expect(json[:slug]).to eq("abcdefgh")
      expect(json[:url]).to eq(landing_page.url)
      expect(json[:product_id]).to eq(landing_page.product.external_id)
      expect(json[:product_permalink]).to eq(landing_page.product.unique_permalink)
      expect(json[:name]).to eq("Spring sale")
      expect(json[:description]).to eq("<p>Hi</p>")
      expect(json[:custom_summary]).to eq("Summary")
      expect(json[:custom_attributes]).to eq([{ "name" => "Audience", "value" => "Engineers" }])
      expect(json[:position]).to eq(0)
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end
  end
end
