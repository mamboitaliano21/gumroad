# frozen_string_literal: true

PAGES_DEMO_PERMALINK = "demopage"

def load_pages
  if Rails.env.production?
    puts "Shouldn't run pages seed on production"
    raise
  end

  seller = User.find_by(email: "seller@gumroad.com")
  return unless seller

  product = seller.links.alive.first
  unless product
    product = Link.new(user_id: seller.id, name: "Beautiful widget for Pages demo", filetype: "link", price_cents: 0)
    product.display_product_reviews = true
    product.prices.build(price_cents: 0, recurrence: 0)
    product.save!
  end

  return if Page.find_by(unique_permalink: PAGES_DEMO_PERMALINK)

  checkout_url = "#{UrlService.domain_with_protocol}/checkout?product=#{product.unique_permalink}"
  raw = <<~HTML
    <div class="max-w-2xl mx-auto p-12 font-sans">
      <h1 class="text-4xl font-bold mb-4">Pages demo</h1>
      <p class="text-lg text-gray-700 mb-8">Rendered from a creator-supplied <code>Page</code> record. Any HTML, any Tailwind, one buy button.</p>
      <a href="#{checkout_url}" class="inline-block bg-black text-white px-6 py-3 rounded-md font-semibold">Buy now</a>
    </div>
  HTML
  raise "Pages demo HTML failed sanitize" if Pages::SanitizeHtmlService.new(raw).perform[:errors].any?
  Page.create!(seller_id: seller.id, unique_permalink: PAGES_DEMO_PERMALINK, title: "Pages demo", raw_html: raw)
end

load_pages
