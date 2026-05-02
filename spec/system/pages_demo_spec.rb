# frozen_string_literal: true

require "spec_helper"

describe "Pages — brutalist commerce demo", type: :system, js: true do
  let(:seller) { create(:user) }
  let!(:product) { create(:product, user: seller, price_cents: 1000) }

  let(:html) do
    <<~HTML
      <section class="bg-yellow-300 border-b-[8px] border-black py-32">
        <div class="max-w-5xl mx-auto px-8">
          <h1 class="font-mono text-[160px] leading-none font-black text-black uppercase">
            Buy<br/>this<br/>now.
          </h1>
          <a class="gumroad-button mt-12 inline-block bg-black text-yellow-300 font-mono text-3xl px-8 py-4 border-[8px] border-black"
             href="#{product.long_url}"
             data-gumroad-overlay-checkout="true">
            Get it →
          </a>
        </div>
      </section>
    HTML
  end

  let(:scrubbed) { Pages::HtmlScrubber.call(html, mode: :strict) }

  it "renders the page chromeless and exposes a buy anchor wired through the existing widget" do
    expect(scrubbed[:errors]).to be_empty, "scrubber should accept the brutalist demo: #{scrubbed[:errors].inspect}"

    page_record = create(:page,
                         seller:,
                         title: "Brutalist demo",
                         content_html_raw: html,
                         content_html_sanitized: scrubbed[:html],
                         published: true)
    create(:page_product, page: page_record, product:)

    visit "/pg/#{page_record.slug}"

    expect(page).to have_css("script[src*='/js/gumroad.js']", visible: false)
    expect(page).to have_css("script[src*='/js/gumroad-embed.js']", visible: false)
    expect(page).to have_css("a.gumroad-button[data-gumroad-overlay-checkout='true']", text: "Get it")
    expect(page).to have_css("h1", text: /Buy/)
  end
end
