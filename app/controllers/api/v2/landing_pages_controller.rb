# frozen_string_literal: true

class Api::V2::LandingPagesController < Api::V2::BaseController
  before_action(only: %i[index show]) { doorkeeper_authorize!(*Doorkeeper.configuration.public_scopes.concat([:view_public])) }
  before_action(only: %i[create update destroy]) { doorkeeper_authorize! :edit_products }

  before_action :fetch_product, only: %i[index create]
  before_action :fetch_landing_page_by_slug, only: %i[show update destroy]

  def index
    landing_pages = @product.landing_pages.alive.order(:position, :id)
    success_with_object(:landing_pages, landing_pages)
  end

  def create
    landing_page = @product.landing_pages.build(permitted_params)
    if landing_page.save
      success_with_landing_page(landing_page)
    else
      error_with_creating_object(:landing_page, landing_page)
    end
  end

  def show
    success_with_landing_page(@landing_page)
  end

  def update
    if @landing_page.update(permitted_params)
      success_with_landing_page(@landing_page)
    else
      error_with_object(:landing_page, @landing_page)
    end
  end

  def destroy
    @landing_page.mark_deleted!
    success_with_landing_page
  end

  private
    def permitted_params
      params.permit(:name, :description, :custom_summary, :position, custom_attributes: [:name, :value])
    end

    def fetch_landing_page_by_slug
      @landing_page = LandingPage.alive.find_by(slug: params[:slug])
      return if @landing_page && @landing_page.product.user_id == current_resource_owner&.id

      @landing_page = nil
      error_with_object(:landing_page, nil)
    end

    def success_with_landing_page(landing_page = nil)
      success_with_object(:landing_page, landing_page)
    end
end
