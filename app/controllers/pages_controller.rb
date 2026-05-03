# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :apply_pages_csp

  layout "page"

  def show
    page = Page.find_by(unique_permalink: params[:unique_permalink])
    return redirect_to(UrlService.domain_with_protocol, status: :found) if page.nil?
    return head :gone unless page.published?

    @page = page
  end

  private
    def apply_pages_csp
      use_secure_headers_override(:pages_csp)
    end
end
