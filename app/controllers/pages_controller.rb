# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :authenticate_user!, except: :show
  after_action :verify_authorized, except: :show

  before_action :apply_pages_csp, only: :show
  before_action :set_page, only: [:edit, :update, :destroy]

  layout "inertia", except: :show
  layout false, only: :show

  def index
    authorize Page

    render inertia: "Pages/Index", props: {
      pages: current_seller.pages.alive.order(created_at: :desc).map { |p| PagePresenter.new(p).page_props }
    }
  end

  def new
    authorize Page

    starter_html = ""
    starter_title = ""
    if params[:product].present?
      product = current_seller.products.find_by(unique_permalink: params[:product])
      if product
        starter_html = starter_html_for(product)
        starter_title = product.name
      end
    end

    render inertia: "Pages/New", props: {
      starter_html: starter_html,
      starter_title: starter_title
    }
  end

  def create
    authorize Page

    page = current_seller.pages.new(page_params)
    if page.save
      redirect_to edit_page_path(page.external_id), notice: "Page created."
    else
      redirect_to new_page_path, alert: page.errors.full_messages.to_sentence, inertia: inertia_errors(page)
    end
  end

  def edit
    authorize @page

    render inertia: "Pages/Edit", props: PagePresenter.new(@page).edit_props
  end

  def update
    authorize @page

    if @page.update(page_params)
      redirect_to edit_page_path(@page.external_id), notice: "Page updated."
    else
      redirect_to edit_page_path(@page.external_id), alert: @page.errors.full_messages.to_sentence, inertia: inertia_errors(@page)
    end
  end

  def destroy
    authorize @page

    @page.mark_deleted!
    redirect_to pages_path, notice: "Page deleted."
  end

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

    def set_page
      @page = current_seller.pages.alive.find_by_external_id(params[:id])
      e404 unless @page
    end

    def page_params
      params.require(:page).permit(:title, :raw_html)
    end

    def starter_html_for(product)
      checkout_url = "/checkout?product=#{product.unique_permalink}"
      variants = product.alive_variants.map do |variant|
        {
          name: variant.name,
          formatted_price: product.display_price_for_price_cents(product.price_cents + variant.price_difference_cents),
          checkout_url: "#{checkout_url}&option=#{variant.external_id}"
        }
      end

      render_to_string(
        partial: "pages/starter",
        locals: {
          product:,
          checkout_url:,
          formatted_price: product.price_formatted,
          cover_url: product.thumbnail_or_cover_url,
          description_paragraphs: description_paragraphs_for(product),
          variants:,
          byline: product.user.name_or_username.presence
        }
      )
    end

    def description_paragraphs_for(product)
      return [] if product.description.blank?
      fragment = Nokogiri::HTML.fragment(product.description)
      paragraphs = fragment.search("p, div, li").map { |n| n.text.strip }.reject(&:blank?)
      paragraphs.presence || [fragment.text.strip].reject(&:blank?)
    end
end
