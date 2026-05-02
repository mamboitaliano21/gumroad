# frozen_string_literal: true

# Expands {{product.X}} and {{seller.X}} tokens against the first linked
# product, returning a String. Runs BEFORE HtmlScrubber so token-produced
# URLs flow through the URL allowlist. Unknown tokens are left literal so
# creators spot typos.
module Pages
  class TemplateExpander
    TOKEN_REGEX = /\{\{\s*([a-z_]+(?:\.[a-z_]+)*)\s*\}\}/

    def self.call(html, products: [])
      new(html, products).call
    end

    def initialize(html, products)
      @html = html.to_s
      @product = Array(products).first
    end

    def call
      @html.gsub(TOKEN_REGEX) do |match|
        path = Regexp.last_match(1).split(".")
        value = resolve(path)
        value.nil? ? match : value
      end
    end

    private
      def resolve(path)
        case path
        when %w[product name] then escape(@product&.name)
        when %w[product price] then escape(format_price)
        when %w[product price_cents] then @product ? @product.price_cents.to_s : ""
        when %w[product rating] then @product ? @product.average_rating.to_s : ""
        when %w[product review_count] then @product ? @product.reviews_count.to_s : ""
        when %w[product url] then @product&.long_url.to_s
        when %w[product checkout_url] then checkout_url
        when %w[product thumbnail_url] then @product&.thumbnail&.url.to_s
        when %w[seller name] then escape(@product&.user&.name.presence || @product&.user&.username)
        when %w[seller username] then escape(@product&.user&.username)
        end
      end

      def escape(value)
        ERB::Util.html_escape(value.to_s)
      end

      def format_price
        return "" unless @product
        MoneyFormatter.format(
          @product.price_cents,
          @product.price_currency_type.to_s.downcase.to_sym,
          no_cents_if_whole: true,
          symbol: true
        )
      end

      def checkout_url
        return "" unless @product
        url = @product.long_url
        url.include?("?") ? "#{url}&wanted=true" : "#{url}?wanted=true"
      end
  end
end
