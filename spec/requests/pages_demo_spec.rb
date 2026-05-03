# frozen_string_literal: true

require "spec_helper"

describe "Pages demo flow", :js, type: :system do
  let(:seller) { create(:user) }
  let(:product) { create(:product, user: seller, name: "Beautiful widget", price_cents: 1000) }
  let(:checkout_url) { "#{PROTOCOL}://#{DOMAIN}/checkout?product=#{product.unique_permalink}" }
  let(:page_html) do
    <<~HTML
      <section class="bg-black text-white px-6 py-32 text-center">
        <h1 class="text-7xl font-bold mb-10">Pages demo render</h1>
        <a href="#{checkout_url}" id="page-buy-link" class="inline-block bg-white text-black px-8 py-4 rounded-full">Buy</a>
      </section>
    HTML
  end
  let(:page_record) { create(:page, seller:, raw_html: page_html) }

  it "renders the page chromeless and preserves the buy link href through sanitization" do
    visit "/pg/#{page_record.unique_permalink}"
    expect(page).to have_text("Pages demo render")
    expect(find("#page-buy-link")[:href]).to eq(checkout_url)
  end

  it "navigates from the page to checkout with the product hydrated" do
    visit "/pg/#{page_record.unique_permalink}"
    find("#page-buy-link").click

    expect(page).to have_current_path(/\/checkout/)
    expect(page).to have_text(product.name)
  end
end
