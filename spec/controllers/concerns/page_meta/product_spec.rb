# frozen_string_literal: true

require "spec_helper"
require "inertia_rails/rspec"

describe PageMeta::Product, type: :controller do
  controller(ApplicationController) do
    include PageMeta::Product

    def action
      set_product_page_meta(Link.find(params[:id]))
      render inertia: "Anonymous"
    end
  end

  before do
    routes.draw { get :action, to: "anonymous#action" }
  end

  describe "image preload meta tags", inertia: true do
    let(:product) { create(:product) }
    let(:file_double) { double("attached_file", image?: true).as_null_object }
    let(:asset_preview) { double("AssetPreview", file: file_double).as_null_object }

    before do
      allow(asset_preview).to receive(:url).with(no_args).and_return("https://cdn.example.com/retina-url.png")
      allow(asset_preview).to receive(:url).with(style: :original).and_return("https://cdn.example.com/original-url.png")
      allow_any_instance_of(Link).to receive(:display_asset_previews).and_return([asset_preview])
    end

    it "does not trigger image processing by avoiding the default (retina) style URL" do
      expect(asset_preview).not_to receive(:url).with(no_args)
      expect(asset_preview).to receive(:url).with(style: :original).at_least(:once).and_return("https://cdn.example.com/original-url.png")

      get :action, params: { id: product.id }

      expect(response).to be_successful
    end

    it "adds a preload link tag pointing at the original asset URL" do
      get :action, params: { id: product.id }

      preload_tag = inertia.props[:_inertia_meta].find do |tag|
        tag[:rel] == "preload" && tag[:as] == "image"
      end

      expect(preload_tag).to be_present
      expect(preload_tag[:href]).to eq("https://cdn.example.com/original-url.png")
    end
  end
end
