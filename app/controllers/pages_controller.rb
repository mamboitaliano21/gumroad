# frozen_string_literal: true

class PagesController < Sellers::BaseController
  before_action :set_page, only: [:edit, :update, :destroy]

  layout "inertia"

  def index
    authorize Page

    render inertia: "Pages/Index", props: {
      pages: -> { current_seller.pages.alive.order(created_at: :desc).map { |p| PagePresenter.new(p).list_props } }
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
      redirect_to edit_page_path(page), notice: "Page created."
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
      redirect_to edit_page_path(@page), notice: "Page updated."
    else
      redirect_to edit_page_path(@page), alert: @page.errors.full_messages.to_sentence, inertia: inertia_errors(@page)
    end
  end

  def destroy
    authorize @page

    @page.mark_deleted!
    redirect_to pages_path, notice: "Page deleted."
  end

  private
    def set_page
      @page = current_seller.pages.alive.find(params[:id])
    end

    def page_params
      params.require(:page).permit(:title, :raw_html)
    end

    def starter_html_for(product)
      checkout_url = "/checkout?product=#{product.unique_permalink}"
      currency = product.price_currency_type.to_sym
      variants = product.alive_variants.map do |variant|
        {
          name: variant.name,
          formatted_price: MoneyFormatter.format(product.price_cents + variant.price_difference_cents, currency, no_cents_if_whole: true, symbol: true),
          checkout_url: "#{checkout_url}&option=#{variant.external_id}"
        }
      end
      primary_cta_href = variants.any? ? "#pricing" : checkout_url
      primary_cta_target = variants.any? ? "_self" : "_top"
      primary_cta_label = variants.any? ? "Pick a tier" : "Get it for #{MoneyFormatter.format(product.price_cents, currency, no_cents_if_whole: true, symbol: true)}"

      render_to_string(
        partial: "pages/starter",
        locals: {
          product:,
          checkout_url:,
          formatted_price: MoneyFormatter.format(product.price_cents, currency, no_cents_if_whole: true, symbol: true),
          cover_url: product.thumbnail_or_cover_url,
          description_paragraphs: description_paragraphs_for(product),
          variants:,
          byline: product.user.name_or_username.presence,
          primary_cta_href:,
          primary_cta_target:,
          primary_cta_label:
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
