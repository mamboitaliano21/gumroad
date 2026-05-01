# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorized_oauth_v1_api_method"

describe Api::V2::LandingPagesController do
  before do
    @user = create(:user)
    @app = create(:oauth_application, owner: create(:user))
    @product = create(:product, user: @user)
  end

  describe "GET 'index'" do
    before do
      @action = :index
      @params = { link_id: @product.external_id }
    end

    it_behaves_like "authorized oauth v1 api method"

    describe "when logged in with view_public scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @user.id, scopes: "view_public")
        @params.merge!(access_token: @token.token)
      end

      it "returns the empty list when there are no landing pages" do
        get @action, params: @params
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["landing_pages"]).to eq([])
      end

      it "returns alive landing pages ordered by position then id" do
        third = create(:landing_page, product: @product, position: 5)
        first = create(:landing_page, product: @product, position: 0)
        second = create(:landing_page, product: @product, position: 0)
        create(:landing_page, product: @product).mark_deleted!

        get @action, params: @params
        slugs = response.parsed_body["landing_pages"].map { _1["slug"] }
        expect(slugs).to eq([first.slug, second.slug, third.slug])
      end

      it "does not return landing pages from other products" do
        my_landing_page = create(:landing_page, product: @product)
        other_product = create(:product, user: @user)
        create(:landing_page, product: other_product)

        get @action, params: @params
        slugs = response.parsed_body["landing_pages"].map { _1["slug"] }
        expect(slugs).to eq([my_landing_page.slug])
      end
    end
  end

  describe "POST 'create'" do
    before do
      @action = :create
      @params = { link_id: @product.external_id, name: "Spring sale", description: "<p>Limited time.</p>" }
    end

    it_behaves_like "authorized oauth v1 api method"
    it_behaves_like "authorized oauth v1 api method only for edit_products scope"

    describe "when logged in with edit_products scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @user.id, scopes: "edit_products")
        @params.merge!(access_token: @token.token)
      end

      it "creates a landing page with a server-generated slug" do
        post @action, params: @params

        expect(response.parsed_body["success"]).to be true
        expect(@product.reload.landing_pages.alive.count).to eq(1)
        landing_page = @product.landing_pages.alive.first
        expect(landing_page.slug).to match(LandingPage::SLUG_FORMAT)
        expect(response.parsed_body["landing_page"]["slug"]).to eq(landing_page.slug)
        expect(response.parsed_body["landing_page"]["url"]).to eq(landing_page.url)
        expect(response.parsed_body["landing_page"]["name"]).to eq("Spring sale")
      end

      it "ignores any user-supplied slug parameter" do
        post @action, params: @params.merge(slug: "userpick")

        expect(response.parsed_body["success"]).to be true
        landing_page = @product.landing_pages.alive.first
        expect(landing_page.slug).not_to eq("userpick")
      end

      it "accepts custom attributes" do
        post @action, params: @params.merge(custom_attributes: [{ name: "Audience", value: "Engineers" }])

        landing_page = @product.landing_pages.alive.first
        expect(landing_page.custom_attributes).to eq([{ "name" => "Audience", "value" => "Engineers" }])
      end

      it "returns an error when the per-product cap is reached" do
        stub_const("LandingPage::PER_PRODUCT_LIMIT", 1)
        create(:landing_page, product: @product)

        post @action, params: @params

        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["message"]).to include("Cannot create more than 1 landing pages per product")
      end
    end
  end

  describe "GET 'show'" do
    let!(:landing_page) { create(:landing_page, product: @product, name: "My LP") }

    before do
      @action = :show
      @params = { slug: landing_page.slug }
    end

    it_behaves_like "authorized oauth v1 api method"

    describe "when logged in with view_public scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @user.id, scopes: "view_public")
        @params.merge!(access_token: @token.token)
      end

      it "returns the landing page details addressed by slug alone" do
        get @action, params: @params

        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["landing_page"]["slug"]).to eq(landing_page.slug)
        expect(response.parsed_body["landing_page"]["name"]).to eq("My LP")
      end

      it "returns an error when the slug does not exist" do
        get @action, params: @params.merge(slug: "deadbeef")

        expect(response.parsed_body["success"]).to be false
      end

      it "does not expose another seller's landing page" do
        other_user = create(:user)
        other_token = create("doorkeeper/access_token", application: @app, resource_owner_id: other_user.id, scopes: "view_public")

        get @action, params: { slug: landing_page.slug, access_token: other_token.token }

        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "PUT 'update'" do
    let!(:landing_page) { create(:landing_page, product: @product, name: "Old name") }

    before do
      @action = :update
      @params = { slug: landing_page.slug, name: "New name" }
    end

    it_behaves_like "authorized oauth v1 api method"
    it_behaves_like "authorized oauth v1 api method only for edit_products scope"

    describe "when logged in with edit_products scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @user.id, scopes: "edit_products")
        @params.merge!(access_token: @token.token)
      end

      it "updates the landing page" do
        put @action, params: @params

        expect(response.parsed_body["success"]).to be true
        expect(landing_page.reload.name).to eq("New name")
        expect(response.parsed_body["landing_page"]["name"]).to eq("New name")
      end

      it "does not allow updating another seller's landing page" do
        other_user = create(:user)
        other_token = create("doorkeeper/access_token", application: @app, resource_owner_id: other_user.id, scopes: "edit_products")

        put @action, params: { slug: landing_page.slug, access_token: other_token.token, name: "Hijacked" }

        expect(response.parsed_body["success"]).to be false
        expect(landing_page.reload.name).to eq("Old name")
      end
    end
  end

  describe "DELETE 'destroy'" do
    let!(:landing_page) { create(:landing_page, product: @product) }

    before do
      @action = :destroy
      @params = { slug: landing_page.slug }
    end

    it_behaves_like "authorized oauth v1 api method"
    it_behaves_like "authorized oauth v1 api method only for edit_products scope"

    describe "when logged in with edit_products scope" do
      before do
        @token = create("doorkeeper/access_token", application: @app, resource_owner_id: @user.id, scopes: "edit_products")
        @params.merge!(access_token: @token.token)
      end

      it "soft-deletes the landing page" do
        delete @action, params: @params

        expect(response.parsed_body["success"]).to be true
        expect(landing_page.reload.deleted?).to be true
      end

      it "does not delete another seller's landing page" do
        other_user = create(:user)
        other_token = create("doorkeeper/access_token", application: @app, resource_owner_id: other_user.id, scopes: "edit_products")

        delete @action, params: { slug: landing_page.slug, access_token: other_token.token }

        expect(response.parsed_body["success"]).to be false
        expect(landing_page.reload.alive?).to be true
      end
    end
  end
end
