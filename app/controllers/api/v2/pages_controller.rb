# frozen_string_literal: true

class Api::V2::PagesController < Api::V2::BaseController
  PAGES_PER_PAGE = 50

  before_action(only: %i[index show]) { doorkeeper_authorize!(*Doorkeeper.configuration.public_scopes.concat([:view_public])) }
  before_action(only: %i[create update destroy sanitize]) { doorkeeper_authorize! :edit_products }
  before_action :fetch_page, only: %i[show update destroy]

  def index
    pages = current_resource_owner.pages.alive.order(created_at: :desc, id: :desc).limit(PAGES_PER_PAGE)
    success_with_object(:pages, pages.map { serialize(_1) })
  end

  def show
    success_with_object(:page, serialize(@page))
  end

  def create
    products = resolve_products(params[:product_permalinks])
    sanitization = expand_and_sanitize_or_render_error(params[:content_html], products: products)
    return if sanitization.nil?

    page = current_resource_owner.pages.build(
      title: params[:title].to_s.strip,
      content_html_raw: params[:content_html].to_s,
      content_html_sanitized: sanitization[:html],
      published: parse_published(params[:published]),
    )
    page.settings_json = build_settings(params[:settings])

    if page.save
      attach_products!(page, products)
      success_with_object(:page, serialize(page))
    else
      error_with_creating_object(:page, page)
    end
  end

  def update
    products = params.key?(:product_permalinks) ? resolve_products(params[:product_permalinks]) : @page.products.to_a

    if params.key?(:content_html)
      sanitization = expand_and_sanitize_or_render_error(params[:content_html], products: products)
      return if sanitization.nil?
      @page.content_html_raw = params[:content_html].to_s
      @page.content_html_sanitized = sanitization[:html]
    end

    @page.title = params[:title].to_s.strip if params.key?(:title)
    @page.published = parse_published(params[:published]) if params.key?(:published)
    @page.settings_json = build_settings(params[:settings]) if params.key?(:settings)

    if @page.save
      attach_products!(@page, products) if params.key?(:product_permalinks)
      success_with_object(:page, serialize(@page))
    else
      error_with_object(:page, @page)
    end
  end

  def destroy
    if @page.mark_deleted
      success_with_object(:page, nil)
    else
      error_with_object(:page, @page)
    end
  end

  def sanitize
    products = resolve_products(params[:product_permalinks])
    expanded = Pages::TemplateExpander.call(params[:content_html].to_s, products: products)
    result = Pages::HtmlScrubber.call(expanded, mode: parse_mode(:lossy))
    render_response(true, html: result[:html], errors: result[:errors])
  end

  private
    def fetch_page
      @page = current_resource_owner.pages.alive.find_by(slug: params[:slug])
      error_with_object(:page, nil) if @page.nil?
    end

    def parse_mode(default = :strict)
      raw = params[:mode].to_s.downcase
      return :lossy if raw == "lossy"
      return :strict if raw == "strict"
      default
    end

    def parse_published(value)
      return false if value.nil?
      ActiveModel::Type::Boolean.new.cast(value) || false
    end

    def build_settings(value)
      return Page::DEFAULT_SETTINGS.dup if value.blank?
      hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
      Page::DEFAULT_SETTINGS.merge(hash.transform_keys(&:to_s))
    end

    def expand_and_sanitize_or_render_error(html, products:)
      mode = parse_mode
      expanded = Pages::TemplateExpander.call(html.to_s, products: products)
      result = Pages::HtmlScrubber.call(expanded, mode:)
      if mode == :strict && result[:errors].any?
        render_response(false,
                        message: "Page content contains disallowed HTML. Use mode=lossy to silently strip, or fix the listed issues and retry.",
                        errors: result[:errors])
        return nil
      end
      result
    end

    def resolve_products(permalinks)
      return [] if permalinks.blank?
      identifiers = Array(permalinks).flat_map { _1.is_a?(String) ? _1.split(",") : _1 }.map { _1.to_s.strip }.reject(&:blank?)
      products = current_resource_owner.links.where(unique_permalink: identifiers).to_a
      products += current_resource_owner.links.by_external_ids(identifiers - products.map(&:unique_permalink)).to_a
      products.uniq
    end

    def attach_products!(page, products)
      return if products.blank?
      page.page_products.where.not(product_id: products.map(&:id)).destroy_all
      products.each_with_index do |product, idx|
        existing = page.page_products.find_by(product_id: product.id)
        if existing
          existing.update!(position: idx)
        else
          page.page_products.create!(product_id: product.id, position: idx)
        end
      end
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
