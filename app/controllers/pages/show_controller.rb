# frozen_string_literal: true

module Pages
  class ShowController < ApplicationController
    before_action :apply_pages_csp

    layout false

    def show
      page = Page.alive.find_by(permalink: params[:permalink])
      return e404 if page.nil? || !Feature.active?(:pages, page.seller)
      @page = page
      render "pages/show/show"
    end

    private
      def apply_pages_csp
        use_secure_headers_override(:pages_csp)
      end
  end
end
