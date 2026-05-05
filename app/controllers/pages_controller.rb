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
      <<~HTML
        <main class="mx-auto max-w-2xl p-8 text-center">
          <h1 class="text-4xl font-bold">#{ERB::Util.html_escape(product.name)}</h1>
          <p class="mt-4 text-lg text-gray-700">Edit this HTML to design your product page.</p>
          <a href="#{checkout_url}" target="_top" class="mt-8 inline-block rounded bg-black px-6 py-3 text-white">Buy now</a>
        </main>
      HTML
    end
end
