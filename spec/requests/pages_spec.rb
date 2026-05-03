# frozen_string_literal: true

require "spec_helper"

describe "Pages public render", type: :request do
  before { host! DOMAIN }

  let(:seller) { create(:user) }
  let(:safe_html) do
    <<~HTML
      <section class="bg-yellow-300 border-b-[8px] border-black py-32">
        <h1 class="font-mono text-[160px]">Buy this</h1>
        <a href="https://example.com/checkout?product=abc" class="bg-black text-white px-8 py-4">Buy</a>
      </section>
    HTML
  end

  let(:page_record) { create(:page, seller:, raw_html: safe_html) }

  it "returns 200 with the chromeless layout for a published page" do
    get "/pg/#{page_record.unique_permalink}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>#{page_record.title}</title>")
    expect(response.body).to include("cdn.tailwindcss.com")
    expect(response.body).to include('name="robots" content="noindex"')
    expect(response.body).to include("rel=\"canonical\"")
    expect(response.body).to include("bg-yellow-300")
  end

  it "does not include the legacy widget JS in the layout" do
    get "/pg/#{page_record.unique_permalink}"
    expect(response.body).not_to include("/js/gumroad.js")
    expect(response.body).not_to include("/js/gumroad-embed.js")
  end

  it "returns 410 for a soft-deleted page" do
    page_record.mark_deleted!
    get "/pg/#{page_record.unique_permalink}"
    expect(response).to have_http_status(:gone)
  end

  it "returns 410 for a page with unpublished_at set" do
    page_record.update!(unpublished_at: Time.current)
    get "/pg/#{page_record.unique_permalink}"
    expect(response).to have_http_status(:gone)
  end

  it "returns 302 to the gumroad.com home for an unknown permalink" do
    get "/pg/zzz"
    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(UrlService.domain_with_protocol)
  end

  it "sets the per-route enforced CSP header" do
    get "/pg/#{page_record.unique_permalink}"
    csp = response.headers["Content-Security-Policy"]
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("base-uri 'none'")
    expect(csp).to include("form-action 'none'")
    expect(csp).to include("cdn.tailwindcss.com")
    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_blank
  end

  it "never renders sanitizer-stripped content" do
    create(:page, seller:, unique_permalink: "xsstest1",
                  raw_html: "<script>alert(1)</script><p>kept</p>")
    get "/pg/xsstest1"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("alert(1)")
    expect(response.body).not_to include("<script>")
  end
end
