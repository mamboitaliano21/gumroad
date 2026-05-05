# frozen_string_literal: true

require "spec_helper"

describe "Pages public render", type: :request do
  let(:seller) { create(:user) }

  before do
    allow_any_instance_of(ActionDispatch::Request).to receive(:host).and_return(VALID_REQUEST_HOSTS.first)
    allow_any_instance_of(Pages::CompileTailwindService).to receive(:perform).and_return("/* stub */")
    Feature.activate(:pages)
  end

  after do
    Feature.deactivate(:pages)
  end

  it "renders an iframe wrapper with the locked sandbox attribute" do
    page = create(:page, seller: seller, raw_html: "<div>hello</div>")
    get "/p/#{page.permalink}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/<iframe[^>]*sandbox="allow-top-navigation-by-user-activation"/)
    expect(response.body).not_to match(/sandbox="[^"]*allow-scripts/)
    expect(response.body).not_to match(/sandbox="[^"]*allow-same-origin/)
  end

  it "inlines compiled CSS and sanitized HTML in srcdoc" do
    page = create(:page, seller: seller, raw_html: "<div>placeholder</div>")
    allow_any_instance_of(Pages::CompileTailwindService).to receive(:perform).and_return(".marker-css{}")
    page.update!(raw_html: "<div>marker-text</div>")
    get "/p/#{page.permalink}"
    expect(response.body).to include("marker-text")
    expect(response.body).to include("marker-css")
  end

  it "sets per-route CSP override to script-src 'self'" do
    page = create(:page, seller: seller)
    get "/p/#{page.permalink}"
    csp = response.headers["Content-Security-Policy"].to_s
    expect(csp).to match(/script-src 'self'(?:\s|;|$)/)
    expect(csp).not_to include("cdn.tailwindcss.com")
  end

  it "returns 404 when permalink is missing" do
    get "/p/nonexistent"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when the page is soft-deleted" do
    page = create(:page, seller: seller)
    page.mark_deleted!
    get "/p/#{page.permalink}"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when the Flipper flag is off for the seller" do
    Feature.deactivate(:pages)
    page = create(:page, seller: seller)
    get "/p/#{page.permalink}"
    expect(response).to have_http_status(:not_found)
  end
end
