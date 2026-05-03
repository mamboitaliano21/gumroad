# frozen_string_literal: true

require "spec_helper"

describe Pages::TemplateExpander do
  def expand(html, products: [])
    described_class.call(html, products:)
  end

  describe "with a linked product" do
    let(:seller) { create(:user, name: "Gumbo film", username: "gumbofilm") }
    let(:product) { create(:product, user: seller, name: "Beautiful films widget", price_cents: 500, price_currency_type: "usd") }

    it "expands product.name" do
      expect(expand("Hello {{product.name}}", products: [product])).to eq("Hello Beautiful films widget")
    end

    it "expands product.price as a formatted currency string" do
      expect(expand("{{product.price}}", products: [product])).to eq("$5")
    end

    it "expands product.price_cents as raw integer string" do
      expect(expand("{{product.price_cents}}", products: [product])).to eq("500")
    end

    it "expands product.rating to the average rating string" do
      create(:product_review_stat, link: product, reviews_count: 12, average_rating: 4.8)
      expect(expand("{{product.rating}}", products: [product.reload])).to eq("4.8")
    end

    it "expands product.review_count to the reviews count string" do
      create(:product_review_stat, link: product, reviews_count: 12, average_rating: 4.8)
      expect(expand("{{product.review_count}}", products: [product.reload])).to eq("12")
    end

    it "expands product.rating and product.review_count to defaults when no review stat exists" do
      expect(expand("{{product.rating}} ({{product.review_count}})", products: [product])).to eq("0.0 (0)")
    end

    it "expands product.url to the long_url" do
      expect(expand("{{product.url}}", products: [product])).to eq(product.long_url)
    end

    it "expands product.description verbatim so the downstream HtmlScrubber sees real HTML" do
      product.update!(description: "<p>Hello <strong>world</strong></p>")
      expect(expand("{{product.description}}", products: [product])).to eq("<p>Hello <strong>world</strong></p>")
    end

    it "expands product.cover_url to the first display asset preview's URL" do
      preview = double("AssetPreview", url: "https://cdn.example.com/cover.png")
      allow(product).to receive(:display_asset_previews).and_return([preview])
      expect(expand("{{product.cover_url}}", products: [product])).to eq("https://cdn.example.com/cover.png")
    end

    it "expands seller.avatar_url to the user's avatar URL" do
      allow(product.user).to receive(:avatar_url).and_return("https://cdn.example.com/avatar.png")
      expect(expand("{{seller.avatar_url}}", products: [product])).to eq("https://cdn.example.com/avatar.png")
    end

    it "expands product.checkout_url to the canonical /checkout page URL" do
      expect(expand("{{product.checkout_url}}", products: [product])).to eq("#{UrlService.domain_with_protocol}/checkout?product=#{product.unique_permalink}")
    end

    it "expands seller.name (falling back to username when name is blank)" do
      expect(expand("{{seller.name}}", products: [product])).to eq("Gumbo film")
      seller.update!(name: nil)
      expect(expand("{{seller.name}}", products: [product.reload])).to eq("gumbofilm")
    end

    it "expands seller.username" do
      expect(expand("{{seller.username}}", products: [product])).to eq("gumbofilm")
    end

    it "uses the FIRST product when multiple are linked" do
      other = create(:product, user: seller, name: "Second product")
      expect(expand("{{product.name}}", products: [product, other])).to eq("Beautiful films widget")
    end

    it "handles tokens in attribute context" do
      html = '<a href="{{product.checkout_url}}" class="btn">Buy {{product.name}}</a>'
      expanded = expand(html, products: [product])
      expect(expanded).to eq(%(<a href="#{UrlService.domain_with_protocol}/checkout?product=#{product.unique_permalink}" class="btn">Buy Beautiful films widget</a>))
    end

    it "supports whitespace inside the braces" do
      expect(expand("{{ product.name }}", products: [product])).to eq("Beautiful films widget")
    end

    it "expands multiple distinct tokens in one document" do
      html = "<h1>{{product.name}}</h1><p>{{product.price}} from {{seller.name}}</p>"
      expect(expand(html, products: [product])).to eq("<h1>Beautiful films widget</h1><p>$5 from Gumbo film</p>")
    end
  end

  describe "indexed tokens" do
    let(:seller) { create(:user, name: "Goodsnooze", username: "goodsnooze") }
    let(:product) { create(:product, user: seller, price_cents: 0, price_currency_type: "eur") }

    before do
      cover_a = double("AssetPreview", url: "https://cdn.example.com/cover-a.png")
      cover_b = double("AssetPreview", url: "https://cdn.example.com/cover-b.png")
      allow(product).to receive(:display_asset_previews).and_return([cover_a, cover_b])

      free = double("Variant", name: "MacWhisper Free", description: "Native macOS app", price_difference_cents: 0, external_id: "freeext")
      pro = double("Variant", name: "MacWhisper Pro", description: "1 Pro license", price_difference_cents: 6400, external_id: "proext")
      relation = double("ActiveRecord::Relation")
      allow(relation).to receive(:in_order).and_return([free, pro])
      allow(product).to receive(:alive_variants).and_return(relation)
    end

    it "expands product.covers[N].url to the Nth display asset preview's URL" do
      expect(expand("{{product.covers[0].url}}", products: [product])).to eq("https://cdn.example.com/cover-a.png")
      expect(expand("{{product.covers[1].url}}", products: [product])).to eq("https://cdn.example.com/cover-b.png")
    end

    it "expands product.variants[N].name to the Nth variant's name" do
      expect(expand("{{product.variants[0].name}}", products: [product])).to eq("MacWhisper Free")
      expect(expand("{{product.variants[1].name}}", products: [product])).to eq("MacWhisper Pro")
    end

    it "expands product.variants[N].price to base + price_difference, formatted in the product's currency" do
      expect(expand("{{product.variants[0].price}}", products: [product])).to eq("€0")
      expect(expand("{{product.variants[1].price}}", products: [product])).to eq("€64")
    end

    it "expands product.variants[N].description" do
      expect(expand("{{product.variants[0].description}}", products: [product])).to eq("Native macOS app")
    end

    it "expands product.variants[N].checkout_url to the canonical /checkout URL with the variant's option" do
      expect(expand("{{product.variants[0].checkout_url}}", products: [product])).to eq("#{UrlService.domain_with_protocol}/checkout?product=#{product.unique_permalink}&option=freeext")
      expect(expand("{{product.variants[1].checkout_url}}", products: [product])).to eq("#{UrlService.domain_with_protocol}/checkout?product=#{product.unique_permalink}&option=proext")
    end

    it "applies a non-zero base price when computing variant.price" do
      paid_product = create(:product, user: seller, price_cents: 500, price_currency_type: "usd")
      pro = double("Variant", name: "Pro", description: "x", price_difference_cents: 6400)
      relation = double("ActiveRecord::Relation")
      allow(relation).to receive(:in_order).and_return([pro])
      allow(paid_product).to receive(:alive_variants).and_return(relation)
      expect(expand("{{product.variants[0].price}}", products: [paid_product])).to eq("$69")
    end

    it "expands an out-of-bounds covers index to an empty string" do
      expect(expand("{{product.covers[99].url}}", products: [product])).to eq("")
    end

    it "expands out-of-bounds variants indices to empty strings" do
      expect(expand("{{product.variants[99].name}}", products: [product])).to eq("")
      expect(expand("{{product.variants[99].price}}", products: [product])).to eq("")
      expect(expand("{{product.variants[99].description}}", products: [product])).to eq("")
      expect(expand("{{product.variants[99].checkout_url}}", products: [product])).to eq("")
    end

    it "HTML-escapes variant.name and variant.description text values" do
      malicious = double("Variant", name: "<script>", description: "<img onerror=x>", price_difference_cents: 0)
      relation = double("ActiveRecord::Relation")
      allow(relation).to receive(:in_order).and_return([malicious])
      allow(product).to receive(:alive_variants).and_return(relation)
      expect(expand("{{product.variants[0].name}}", products: [product])).to eq("&lt;script&gt;")
      expect(expand("{{product.variants[0].description}}", products: [product])).to eq("&lt;img onerror=x&gt;")
    end
  end

  describe "indexed tokens with no linked products" do
    it "expands product.covers[N].url to an empty string" do
      expect(expand("{{product.covers[0].url}}", products: [])).to eq("")
    end

    it "expands product.variants[N].name to an empty string" do
      expect(expand("{{product.variants[0].name}}", products: [])).to eq("")
    end

    it "expands product.variants[N].price to an empty string" do
      expect(expand("{{product.variants[0].price}}", products: [])).to eq("")
    end

    it "expands product.variants[N].description to an empty string" do
      expect(expand("{{product.variants[0].description}}", products: [])).to eq("")
    end

    it "expands product.variants[N].checkout_url to an empty string" do
      expect(expand("{{product.variants[0].checkout_url}}", products: [])).to eq("")
    end
  end

  describe "HTML escaping in text contexts" do
    let(:seller) { create(:user, name: "Evil <script>alert('xss')</script> seller", username: "evilseller") }
    let(:product) { create(:product, user: seller, name: 'Widget "with quotes" & <b>bold</b>') }

    it "escapes HTML special characters in product.name to prevent injection" do
      expanded = expand("Get {{product.name}}", products: [product])
      expect(expanded).to eq("Get Widget &quot;with quotes&quot; &amp; &lt;b&gt;bold&lt;/b&gt;")
    end

    it "escapes HTML in seller.name even when wrapped in literal HTML" do
      expanded = expand("By {{seller.name}}", products: [product])
      expect(expanded).not_to include("<script>")
      expect(expanded).to include("&lt;script&gt;")
    end
  end

  describe "with no linked products" do
    it "expands product.name to an empty string" do
      expect(expand("Hello {{product.name}}", products: [])).to eq("Hello ")
    end

    it "expands product.url to an empty string" do
      expect(expand('<a href="{{product.url}}">x</a>', products: [])).to eq('<a href="">x</a>')
    end

    it "expands product.thumbnail_url to an empty string" do
      expect(expand("{{product.thumbnail_url}}", products: [])).to eq("")
    end

    it "expands product.rating to an empty string" do
      expect(expand("{{product.rating}}", products: [])).to eq("")
    end

    it "expands product.review_count to an empty string" do
      expect(expand("{{product.review_count}}", products: [])).to eq("")
    end

    it "expands product.description to an empty string" do
      expect(expand("{{product.description}}", products: [])).to eq("")
    end

    it "expands product.cover_url to an empty string" do
      expect(expand("{{product.cover_url}}", products: [])).to eq("")
    end

    it "expands seller.avatar_url to an empty string" do
      expect(expand("{{seller.avatar_url}}", products: [])).to eq("")
    end
  end

  describe "unknown tokens" do
    let(:product) { create(:product) }

    it "leaves an unknown product field literally" do
      expect(expand("{{product.unknown_field}}", products: [product])).to eq("{{product.unknown_field}}")
    end

    it "leaves an unknown namespace literally" do
      expect(expand("{{foo.bar}}", products: [product])).to eq("{{foo.bar}}")
    end

    it "leaves single-segment paths literally" do
      expect(expand("{{name}}", products: [product])).to eq("{{name}}")
    end

    it "ignores braces that don't form a token" do
      html = "css uses { and } for blocks; this { is fine"
      expect(expand(html, products: [product])).to eq(html)
    end
  end

  describe "edge cases" do
    let(:product) { create(:product) }

    it "returns empty string for empty input" do
      expect(expand("", products: [product])).to eq("")
    end

    it "doesn't recurse — token values containing {{...}} are left as text" do
      product.update!(name: "{{product.name}}")
      expect(expand("{{product.name}}", products: [product.reload])).to eq("{{product.name}}")
    end

    it "is a no-op when there are no tokens" do
      html = "<h1>Static content with no tokens</h1>"
      expect(expand(html, products: [product])).to eq(html)
    end
  end
end
