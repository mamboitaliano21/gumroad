# frozen_string_literal: true

class Api::V2::PagesController < Api::V2::BaseController
  PAGES_PER_PAGE = 50

  before_action(only: %i[index show]) { doorkeeper_authorize!(*Doorkeeper.configuration.public_scopes.concat([:view_public])) }
  before_action :fetch_page, only: %i[show]

  def index
    pages = current_resource_owner.pages.alive.order(created_at: :desc, id: :desc).limit(PAGES_PER_PAGE)
    success_with_object(:pages, pages.map { serialize(_1) })
  end

  def show
    success_with_object(:page, serialize(@page))
  end

  private
    def fetch_page
      @page = current_resource_owner.pages.alive.find_by(slug: params[:slug])
      error_with_object(:page, nil) if @page.nil?
    end

    def serialize(page)
      {
        id: page.external_id,
        slug: page.slug,
        title: page.title,
        published: page.published,
        url: "#{UrlService.domain_with_protocol}/pg/#{page.slug}",
        content_html: page.content_html_sanitized,
        content_html_raw: page.content_html_raw,
        settings: page.settings_json,
        product_permalinks: page.products.pluck(:unique_permalink),
        created_at: page.created_at,
        updated_at: page.updated_at,
      }
    end
end
