# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorized_oauth_v1_api_method"

describe Api::V2::PagesController do
  before do
    @seller = create(:user)
    @user = @seller
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

  describe "POST 'create'" do
    before do
      @action = :create
      @params = { title: "My Page", content_html: "<section><h1>Hello</h1></section>" }
    end

    it_behaves_like "authorized oauth v1 api method"
    it_behaves_like "authorized oauth v1 api method only for edit_products scope"

    describe "when logged in with edit_products scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "edit_products")
        @params.merge!(access_token: @token.token)
      end

      it "creates a page and returns the serialized payload" do
        expect { post @action, params: @params }.to change { @seller.pages.alive.count }.by(1)
        body = response.parsed_body
        expect(body["success"]).to be true
        expect(body["page"]["title"]).to eq("My Page")
        expect(body["page"]["content_html"]).to include("<h1>Hello</h1>")
        expect(body["page"]["slug"]).to match(Page::SLUG_FORMAT)
      end

      it "stores raw and sanitized content separately" do
        post @action, params: @params.merge(content_html: "<section>ok<script>bad()</script></section>", mode: "lossy")
        page = @seller.pages.alive.last
        expect(page.content_html_raw).to include("<script>")
        expect(page.content_html_sanitized).not_to include("<script>")
      end

      it "rejects disallowed HTML in strict mode and surfaces line-numbered errors" do
        post @action, params: @params.merge(content_html: "<p>ok</p><script>alert(1)</script>")
        body = response.parsed_body
        expect(body["success"]).to be false
        expect(body["message"]).to include("disallowed")
        expect(body["errors"]).to be_an(Array).and(be_present)
        expect(@seller.pages.count).to eq(0)
      end

      it "links provided product permalinks by unique_permalink" do
        product = create(:product, user: @seller)
        post @action, params: @params.merge(product_permalinks: product.unique_permalink)
        page = @seller.pages.alive.last
        expect(page.products).to contain_exactly(product)
      end

      it "links provided product permalinks by external_id" do
        product = create(:product, user: @seller)
        post @action, params: @params.merge(product_permalinks: product.external_id)
        page = @seller.pages.alive.last
        expect(page.products).to contain_exactly(product)
      end

      it "ignores permalinks that don't belong to the seller" do
        mine = create(:product, user: @seller)
        theirs = create(:product, user: @other_seller)
        post @action, params: @params.merge(product_permalinks: [mine.unique_permalink, theirs.unique_permalink])
        page = @seller.pages.alive.last
        expect(page.products).to contain_exactly(mine)
      end

      it "merges provided settings over the defaults" do
        post @action, params: @params.merge(settings: { layout: "gumroad" })
        page = @seller.pages.alive.last
        expect(page.settings_json["layout"]).to eq("gumroad")
      end

      it "applies DEFAULT_SETTINGS when no settings are provided" do
        post @action, params: @params
        page = @seller.pages.alive.last
        expect(page.settings_json).to eq(Page::DEFAULT_SETTINGS)
      end

      it "returns a validation error when title is blank" do
        post @action, params: @params.merge(title: "")
        body = response.parsed_body
        expect(body["success"]).to be false
        expect(body["message"]).to include("Title")
      end
    end
  end

  describe "PUT 'update'" do
    before do
      @page = create(:page, seller: @seller, title: "Old", content_html_raw: "<p>old</p>", content_html_sanitized: "<p>old</p>")
      @action = :update
      @params = { slug: @page.slug }
    end

    it_behaves_like "authorized oauth v1 api method"
    it_behaves_like "authorized oauth v1 api method only for edit_products scope"

    describe "when logged in with edit_products scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "edit_products")
        @params.merge!(access_token: @token.token)
      end

      it "updates only the title when title is provided" do
        put @action, params: @params.merge(title: "New title")
        expect(@page.reload.title).to eq("New title")
        expect(@page.content_html_raw).to eq("<p>old</p>")
      end

      it "re-sanitizes content_html when provided" do
        put @action, params: @params.merge(content_html: "<section><strong>fresh</strong></section>")
        expect(@page.reload.content_html_raw).to eq("<section><strong>fresh</strong></section>")
        expect(@page.content_html_sanitized).to include("<strong>fresh</strong>")
      end

      it "returns a sanitization error in strict mode without saving" do
        put @action, params: @params.merge(content_html: "<p>ok</p><script>bad()</script>")
        body = response.parsed_body
        expect(body["success"]).to be false
        expect(body["errors"]).to be_present
        expect(@page.reload.content_html_raw).to eq("<p>old</p>")
      end

      it "swaps linked products when product_permalinks is provided" do
        old_product = create(:product, user: @seller)
        new_product = create(:product, user: @seller)
        @page.page_products.create!(product: old_product, position: 0)
        put @action, params: @params.merge(product_permalinks: [new_product.unique_permalink])
        expect(@page.reload.products).to contain_exactly(new_product)
      end

      it "leaves linked products untouched when product_permalinks is omitted" do
        product = create(:product, user: @seller)
        @page.page_products.create!(product: product, position: 0)
        put @action, params: @params.merge(title: "Renamed")
        expect(@page.reload.products).to contain_exactly(product)
      end

      it "toggles published" do
        put @action, params: @params.merge(published: false)
        expect(@page.reload.published).to be false
      end

      it "returns not_found for an unknown slug" do
        put @action, params: @params.merge(slug: "missing0")
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["message"]).to include("not found")
      end

      it "returns not_found for another seller's page" do
        their_page = create(:page, seller: @other_seller)
        put @action, params: @params.merge(slug: their_page.slug, title: "Hijacked")
        expect(response.parsed_body["success"]).to be false
        expect(their_page.reload.title).not_to eq("Hijacked")
      end
    end
  end

  describe "DELETE 'destroy'" do
    before do
      @page = create(:page, seller: @seller)
      @action = :destroy
      @params = { slug: @page.slug }
    end

    it_behaves_like "authorized oauth v1 api method"
    it_behaves_like "authorized oauth v1 api method only for edit_products scope"

    describe "when logged in with edit_products scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @seller.id, scopes: "edit_products")
        @params.merge!(access_token: @token.token)
      end

      it "soft-deletes the page" do
        expect { delete @action, params: @params }.to change { @page.reload.deleted? }.from(false).to(true)
      end

      it "returns the deleted-message envelope" do
        delete @action, params: @params
        expect(response.parsed_body).to eq({ "success" => true, "message" => "The page was deleted successfully." })
      end

      it "returns not_found for an unknown slug" do
        delete @action, params: @params.merge(slug: "missing0")
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["message"]).to include("not found")
      end

      it "returns not_found for another seller's page" do
        their_page = create(:page, seller: @other_seller)
        delete @action, params: @params.merge(slug: their_page.slug)
        expect(response.parsed_body["success"]).to be false
        expect(their_page.reload.deleted?).to be false
      end
    end
  end
end
