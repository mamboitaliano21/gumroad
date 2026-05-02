# frozen_string_literal: true

class PagesController < ApplicationController
  layout false

  def show
    @page = Page.alive.find_by(slug: params[:slug])
    return head :not_found if @page.nil? || !@page.published?
    render layout: page_layout
  end

  private
    def page_layout
      @page.chromeless? ? "page" : "application"
    end
end
