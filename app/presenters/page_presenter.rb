# frozen_string_literal: true

class PagePresenter
  include Rails.application.routes.url_helpers

  attr_reader :page

  def initialize(page)
    @page = page
  end

  def list_props
    {
      id: page.id,
      title: page.title,
      permalink: page.permalink,
      public_url: public_url,
      updated_at: page.updated_at.iso8601
    }
  end

  def edit_props
    {
      page: {
        id: page.id,
        title: page.title,
        permalink: page.permalink,
        raw_html: page.raw_html.to_s,
        public_url: public_url
      }
    }
  end

  private
    def public_url
      public_page_url(permalink: page.permalink, host: DOMAIN, protocol: PROTOCOL)
    end
end
