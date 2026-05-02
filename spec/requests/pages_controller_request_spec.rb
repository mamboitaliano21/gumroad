# frozen_string_literal: true

require "spec_helper"

describe "Pages public render", type: :request do
  before { host! DOMAIN }

  let(:seller) { create(:user) }
  let(:safe_html) do
    <<~HTML
      <section class="bg-yellow-300 border-b-[8px] border-black py-32">
        <h1 class="font-mono text-[160px]">Buy this</h1>
      </section>
    HTML
  end

  let(:scrubbed) do
    Pages::HtmlScrubber.call(safe_html, mode: :strict)[:html]
  end

  let(:page) do
    create(:page, seller:, content_html_raw: safe_html, content_html_sanitized: scrubbed, published: true)
  end

  it "returns 200 with the chromeless layout for a published page" do
    get "/pg/#{page.slug}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>#{page.title}</title>")
    expect(response.body).to include("cdn.tailwindcss.com")
    expect(response.body).to include("/js/gumroad.js")
    expect(response.body).to include("/js/gumroad-embed.js")
    expect(response.body).to include("bg-yellow-300")
    expect(response.body).to include("rel=\"canonical\"")
  end

  it "returns 404 for a deleted page" do
    page.mark_deleted!
    get "/pg/#{page.slug}"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for an unpublished page" do
    page.update!(published: false)
    get "/pg/#{page.slug}"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for an unknown slug" do
    get "/pg/zzzzzzzz"
    expect(response).to have_http_status(:not_found)
  end

  it "renders the gumroad layout when settings opt in" do
    page.update!(settings_json: { "layout" => "gumroad" })
    get "/pg/#{page.slug}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("cdn.tailwindcss.com")
  end

  it "never renders sanitizer-stripped content" do
    create(:page, seller:, slug: "xssabcd1", content_html_raw: "<script>alert(1)</script>",
                  content_html_sanitized: Pages::HtmlScrubber.call("<script>alert(1)</script>", mode: :lossy)[:html],
                  published: true)
    get "/pg/xssabcd1"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("alert(1)")
    expect(response.body).not_to include("<script>")
  end
end
