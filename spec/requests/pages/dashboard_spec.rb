# frozen_string_literal: true

require "spec_helper"

describe "Pages dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:seller) { create(:user) }

  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = original
  end

  before do
    allow_any_instance_of(ActionDispatch::Request).to receive(:host).and_return(VALID_REQUEST_HOSTS.first)
    allow_any_instance_of(Pages::CompileTailwindService).to receive(:perform).and_return("/* stub */")
    Feature.activate_user(:pages, seller)
    sign_in seller
  end

  after do
    Feature.deactivate(:pages)
  end

  describe "GET /pages" do
    it "lists the seller's pages" do
      page = create(:page, seller: seller, title: "First")
      get "/pages", headers: { "X-Inertia" => "true" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("First")
      expect(response.body).to include(page.permalink)
    end

    it "redirects to dashboard when Flipper is off (Pundit denies)" do
      Feature.deactivate(:pages)
      Feature.deactivate_user(:pages, seller)
      get "/pages"
      expect(response).to be_redirect
    end
  end

  describe "GET /pages/new" do
    it "pre-fills starter HTML when ?product=PERMALINK is provided" do
      product = create(:product, user: seller, name: "Demo", price_cents: 4900, description: "<p>Line one.</p><p>Line two.</p>")
      get "/pages/new", params: { product: product.unique_permalink }, headers: { "X-Inertia" => "true" }
      expect(response).to have_http_status(:ok)
      props = JSON.parse(response.body)["props"]
      expect(props["starter_html"]).to include("/checkout?product=#{product.unique_permalink}")
      expect(props["starter_html"]).to include("target=\"_top\"")
      expect(props["starter_html"]).to include("$49")
      expect(props["starter_html"]).to include("Line one.")
      expect(props["starter_html"]).to include("Line two.")
      expect(props["starter_title"]).to eq("Demo")
    end

    it "renders a per-variant pricing card when the product has alive variants" do
      product = create(:product, user: seller, name: "Tiered", price_cents: 1000)
      category = create(:variant_category, link: product, title: "Tier")
      basic = create(:variant, variant_category: category, name: "Basic", price_difference_cents: 0)
      pro = create(:variant, variant_category: category, name: "Pro", price_difference_cents: 5000)
      get "/pages/new", params: { product: product.unique_permalink }, headers: { "X-Inertia" => "true" }
      expect(response).to have_http_status(:ok)
      starter_html = JSON.parse(response.body)["props"]["starter_html"]
      expect(starter_html).to include("Basic")
      expect(starter_html).to include("Pro")
      expect(starter_html).to include("option=#{basic.external_id}")
      expect(starter_html).to include("option=#{pro.external_id}")
      expect(starter_html).to include("$10")
      expect(starter_html).to include("$60")
    end
  end

  describe "POST /pages" do
    it "creates a page and redirects to edit" do
      expect do
        post "/pages", params: { page: { title: "T", raw_html: "<div>x</div>" } }
      end.to change(seller.pages, :count).by(1)
      page = seller.pages.last
      expect(response).to redirect_to(edit_page_path(page))
    end

    it "surfaces inertia validation errors when raw_html is blank" do
      post "/pages", params: { page: { title: "T", raw_html: "" } }
      expect(response).to redirect_to(new_page_path)
      expect(session[:inertia_errors]).to be_present
      expect(session[:inertia_errors]["page.raw_html"]).to be_present
    end
  end

  describe "PATCH /pages/:id" do
    it "updates the page" do
      page = create(:page, seller: seller, title: "Old")
      patch "/pages/#{page.id}", params: { page: { title: "New", raw_html: "<div>y</div>" } }
      expect(page.reload.title).to eq("New")
      expect(response).to redirect_to(edit_page_path(page))
    end
  end

  describe "DELETE /pages/:id" do
    it "soft-deletes the page" do
      page = create(:page, seller: seller)
      delete "/pages/#{page.id}"
      expect(page.reload).to be_deleted
      expect(response).to redirect_to(pages_path)
    end
  end

  describe "seller scoping" do
    it "returns 404 when accessing another seller's page" do
      other_page = create(:page, seller: create(:user))
      get "/pages/#{other_page.id}/edit"
      expect(response).to have_http_status(:not_found)
    end
  end
end
