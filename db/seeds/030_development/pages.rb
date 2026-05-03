# frozen_string_literal: true

# Seeds the Apple-style MacWhisper landing-page demo into Pages so the v1
# Pages primitive — sanitized HTML + token expansion + chromeless render +
# checkout — is visible end-to-end out of the box after `bin/rails db:seed`.
#
# Idempotent: skips both the demo product and the Page if they already exist
# under seller@gumroad.com.

def load_pages
  if Rails.env.production?
    puts "Shouldn't run pages seed on production"
    raise
  end

  seller = User.find_by(email: "seller@gumroad.com")
  unless seller
    puts "Skipping pages seed — seller@gumroad.com not present"
    return
  end

  product_name = "MacWhisper Demo"
  cover_urls = [
    "https://public-files.gumroad.com/m9hn7bj9ccmevmqcd5x1z4aqsf3i",
    "https://public-files.gumroad.com/53g1k9kp4o2epz95o28lknsphuod",
  ]
  variants = [
    { name: "MacWhisper Free",  description: "Native macOS app, on-device transcription",      price_difference_cents:     0 },
    { name: "MacWhisper Pro",   description: "Personal use, unlimited transcriptions",         price_difference_cents:  6400 },
    { name: "5 licenses (Pro)", description: "5 Pro licenses for small teams",                 price_difference_cents: 26900 },
  ]

  product = seller.links.find_by(name: product_name)
  unless product
    product = Link.new(
      user_id: seller.id,
      name: product_name,
      filetype: "link",
      price_cents: 0,
      price_currency_type: "eur"
    )
    product.display_product_reviews = true
    product.prices.build(price_cents: 0, recurrence: 0, currency: "eur")
    product.save!

    cover_urls.each { |url| AssetPreview.create!(link: product, unsplash_url: url) }

    category = VariantCategory.create!(link: product, title: "Tier")
    variants.each do |v|
      Variant.create!(
        variant_category: category,
        name: v[:name],
        description: v[:description],
        price_difference_cents: v[:price_difference_cents],
        customizable_price: false
      )
    end
    puts "Created pages demo product — id=#{product.id} permalink=#{product.unique_permalink}"
  end

  page_title = "MacWhisper — Apple-style demo"
  if seller.pages.alive.exists?(title: page_title)
    puts "Pages demo already seeded under #{seller.email}"
    return
  end

  raw = File.read(File.expand_path("pages/macwhisper_demo.html", __dir__))
  expanded = Pages::TemplateExpander.call(raw, products: [product])
  scrubbed = Pages::HtmlScrubber.call(expanded, mode: :strict)
  if scrubbed[:errors].any?
    raise "Pages demo HTML failed strict sanitize: #{scrubbed[:errors].inspect}"
  end

  page = Page.create!(
    seller_id: seller.id,
    title: page_title,
    content_html_raw: raw,
    content_html_sanitized: scrubbed[:html],
    published: true
  )
  PageProduct.create!(page: page, product: product, position: 0)
  puts "Created pages demo — slug=#{page.slug} url=/pg/#{page.slug}"
end

load_pages
