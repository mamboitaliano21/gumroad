# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorized_oauth_v1_api_method"

describe Api::V2::PagesController do
  before do
    @seller = create(:user)
    @other_seller = create(:user)
    @app = create(:oauth_application, owner: create(:user))
  end

  describe "GET 'index'" do
    before do
      @action = :index
      @params = {}
    end

    it_behaves_like "authorized oauth v1 api method"

    describe "when logged in with view_public scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "view_public")
        @params.merge!(access_token: @token.token)
      end

      it "returns an empty array when the seller has no pages" do
        get @action, params: @params
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["pages"]).to eq([])
      end

      it "returns the seller's alive pages, newest first" do
        older = create(:page, seller: @seller, title: "Older")
        newer = create(:page, seller: @seller, title: "Newer")
        get @action, params: @params
        slugs = response.parsed_body["pages"].map { _1["slug"] }
        expect(slugs).to eq([newer.slug, older.slug])
      end

      it "excludes soft-deleted pages" do
        alive = create(:page, seller: @seller)
        deleted = create(:page, seller: @seller).tap(&:mark_deleted!)
        get @action, params: @params
        slugs = response.parsed_body["pages"].map { _1["slug"] }
        expect(slugs).to include(alive.slug)
        expect(slugs).not_to include(deleted.slug)
      end

      it "excludes other sellers' pages" do
        mine = create(:page, seller: @seller)
        create(:page, seller: @other_seller)
        get @action, params: @params
        slugs = response.parsed_body["pages"].map { _1["slug"] }
        expect(slugs).to eq([mine.slug])
      end

      it "limits to PAGES_PER_PAGE results" do
        (Api::V2::PagesController::PAGES_PER_PAGE + 5).times { create(:page, seller: @seller) }
        get @action, params: @params
        expect(response.parsed_body["pages"].size).to eq(Api::V2::PagesController::PAGES_PER_PAGE)
      end
    end

    it "grants access with the account scope" do
      token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "account")
      get @action, params: @params.merge(access_token: token.token)
      expect(response).to be_successful
    end
  end

  describe "GET 'show'" do
    before do
      @page = create(:page, seller: @seller, title: "Profile", content_html_raw: "<p>raw</p>", content_html_sanitized: "<p>safe</p>")
      @action = :show
      @params = { slug: @page.slug }
    end

    it_behaves_like "authorized oauth v1 api method"

    describe "when logged in with view_public scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "view_public")
        @params.merge!(access_token: @token.token)
      end

      it "returns the page payload with all serialized fields" do
        get @action, params: @params
        body = response.parsed_body
        expect(body["success"]).to be true
        page_payload = body["page"]
        expect(page_payload["id"]).to eq(@page.external_id)
        expect(page_payload["slug"]).to eq(@page.slug)
        expect(page_payload["title"]).to eq("Profile")
        expect(page_payload["published"]).to eq(@page.published)
        expect(page_payload["content_html"]).to eq("<p>safe</p>")
        expect(page_payload["content_html_raw"]).to eq("<p>raw</p>")
        expect(page_payload["settings"]).to eq(@page.settings_json)
        expect(page_payload["product_permalinks"]).to eq([])
        expect(page_payload["url"]).to end_with("/pg/#{@page.slug}")
      end

      it "returns linked product permalinks in serialized order" do
        product_a = create(:product, user: @seller)
        product_b = create(:product, user: @seller)
        @page.page_products.create!(product: product_a, position: 0)
        @page.page_products.create!(product: product_b, position: 1)
        get @action, params: @params
        permalinks = response.parsed_body["page"]["product_permalinks"]
        expect(permalinks).to contain_exactly(product_a.unique_permalink, product_b.unique_permalink)
      end

      it "returns an error when the slug is unknown" do
        get @action, params: @params.merge(slug: "nonexist")
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["message"]).to include("not found")
      end

      it "returns an error for another seller's page slug" do
        their_page = create(:page, seller: @other_seller)
        get @action, params: @params.merge(slug: their_page.slug)
        expect(response.parsed_body["success"]).to be false
      end

      it "returns an error for a soft-deleted page" do
        @page.mark_deleted!
        get @action, params: @params
        expect(response.parsed_body["success"]).to be false
      end
    end

    it "grants access with the account scope" do
      token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "account")
      get @action, params: @params.merge(access_token: token.token)
      expect(response).to be_successful
    end
  end
end
