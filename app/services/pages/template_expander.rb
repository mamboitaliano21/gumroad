# frozen_string_literal: true

# Expands {{product.X}} and {{seller.X}} tokens against the first linked
# product, returning a String. Runs BEFORE HtmlScrubber so token-produced
# URLs flow through the URL allowlist. Unknown tokens are left literal so
# creators spot typos.
module Pages
  class TemplateExpander
    TOKEN_REGEX = /\{\{\s*([a-z_]+(?:\[\d+\]|\.[a-z_]+)*)\s*\}\}/
    PATH_SEGMENT_REGEX = /[a-z_]+|\[\d+\]/

    def self.call(html, products: [])
      new(html, products).call
    end

    def initialize(html, products)
      @html = html.to_s
      @product = Array(products).first
    end

    def call
      @html.gsub(TOKEN_REGEX) do |match|
        path = parse_path(Regexp.last_match(1))
        value = resolve(path)
        value.nil? ? match : value
      end
    end

    private
      def parse_path(raw)
        raw.scan(PATH_SEGMENT_REGEX).map { |s| s.start_with?("[") ? Integer(s[1..-2]) : s }
      end

      def resolve(path)
        case path
        in ["product", "name"] then escape(@product&.name)
        in ["product", "price"] then escape(format_price)
        in ["product", "price_cents"] then @product ? @product.price_cents.to_s : ""
        in ["product", "rating"] then @product ? @product.average_rating.to_s : ""
        in ["product", "review_count"] then @product ? @product.reviews_count.to_s : ""
        in ["product", "url"] then @product&.long_url.to_s
        in ["product", "checkout_url"] then checkout_url
        in ["product", "thumbnail_url"] then @product&.thumbnail&.url.to_s
        in ["product", "cover_url"] then @product&.display_asset_previews&.first&.url.to_s
        in ["product", "description"] then @product&.description.to_s
        in ["product", "covers", Integer => i, "url"] then covers[i]&.url.to_s
        in ["product", "variants", Integer => i, "name"] then escape(variants[i]&.name)
        in ["product", "variants", Integer => i, "price"] then escape(format_variant_price(variants[i]))
        in ["product", "variants", Integer => i, "description"] then escape(variants[i]&.description)
        in ["product", "variants", Integer => i, "checkout_url"] then variant_checkout_url(variants[i])
        in ["seller", "name"] then escape(@product&.user&.name.presence || @product&.user&.username)
        in ["seller", "username"] then escape(@product&.user&.username)
        in ["seller", "avatar_url"] then @product&.user&.avatar_url.to_s
        else nil
        end
      end

      def covers
        @covers ||= @product ? @product.display_asset_previews.to_a : []
      end

      def variants
        @variants ||= @product ? @product.alive_variants.in_order.to_a : []
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

      def format_variant_price(variant)
        return "" unless variant && @product
        MoneyFormatter.format(
          @product.price_cents.to_i + variant.price_difference_cents.to_i,
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

      def variant_checkout_url(variant)
        return "" unless @product && variant
        url = @product.long_url
        separator = url.include?("?") ? "&" : "?"
        "#{url}#{separator}wanted=true&option=#{variant.external_id}"
      end
  end
end
