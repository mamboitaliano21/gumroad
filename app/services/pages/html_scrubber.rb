# frozen_string_literal: true

# Strips creator HTML to a Pages-safe subset. Returns
# { html:, errors: [{tag:, attr:, line:, reason:}] }. Stripping behavior is the
# same in :strict and :lossy modes — the mode is a signal to the caller, which
# must refuse to publish when errors are present in :strict mode.
module Pages
  class HtmlScrubber
    ALLOWED_TAGS = %w[
      div section article header footer main aside nav
      h1 h2 h3 h4 h5 h6 p span strong em b i u s small br hr
      ul ol li dl dt dd
      img figure figcaption picture source video audio
      table thead tbody tr th td caption
      pre code blockquote cite kbd
      svg path circle ellipse rect line polyline polygon g defs text tspan use
      a link
    ].freeze

    GLOBAL_ATTRS = %w[class id title lang dir role].freeze

    PER_TAG_ATTRS = {
      "a" => %w[href target rel],
      "img" => %w[src alt width height loading decoding srcset sizes],
      "video" => %w[src controls poster width height autoplay loop muted playsinline preload],
      "audio" => %w[src controls autoplay loop muted preload],
      "source" => %w[src srcset type media sizes],
      "picture" => %w[],
      "th" => %w[scope colspan rowspan abbr],
      "td" => %w[colspan rowspan headers],
      "table" => %w[summary],
      "ol" => %w[start type reversed],
      "li" => %w[value],
      "link" => %w[rel href type as crossorigin],
      "blockquote" => %w[cite],
      "q" => %w[cite],
      "svg" => %w[viewbox xmlns width height fill stroke preserveaspectratio aria-hidden focusable],
      "path" => %w[d fill stroke stroke-width stroke-linecap stroke-linejoin stroke-miterlimit fill-rule clip-rule transform],
      "circle" => %w[cx cy r fill stroke stroke-width transform],
      "ellipse" => %w[cx cy rx ry fill stroke stroke-width transform],
      "rect" => %w[x y width height rx ry fill stroke stroke-width transform],
      "line" => %w[x1 y1 x2 y2 stroke stroke-width transform],
      "polyline" => %w[points fill stroke stroke-width transform],
      "polygon" => %w[points fill stroke stroke-width transform],
      "g" => %w[fill stroke transform],
      "defs" => %w[],
      "text" => %w[x y dx dy text-anchor font-family font-size font-weight fill stroke transform],
      "tspan" => %w[x y dx dy text-anchor font-family font-size font-weight fill],
      "use" => %w[href x y width height transform],
    }.freeze

    DATA_ATTR_ALLOWLIST = %w[
      data-gumroad-overlay-checkout
      data-gumroad-product-id
      data-gumroad-ignore
    ].freeze

    HTTP_SCHEMES = %w[http https].freeze
    IMG_DATA_URL = %r{\Adata:image/(png|jpe?g|gif|webp|svg\+xml|avif|x-icon|bmp);base64,}i

    FONT_HOST_ALLOWLIST = %w[fonts.googleapis.com fonts.gstatic.com fonts.bunny.net].freeze
    FONT_PATH_PREFIXES = {
      "cdn.jsdelivr.net" => "/npm/@fontsource"
    }.freeze

    DEFAULT_ROOT_TAG = "div"

    def self.call(html, mode: :strict)
      new(html, mode:).call
    end

    def initialize(html, mode: :strict)
      @html = html.to_s
      @mode = mode == :lossy ? :lossy : :strict
      @errors = []
    end

    def call
      fragment = Loofah.fragment(@html)
      fragment.scrub!(scrubber)
      sanitized = fragment.to_html
      { html: sanitized, errors: @errors }
    end

    private
      attr_reader :mode

      def scrubber
        Loofah::Scrubber.new do |node|
          process(node)
        end
      end

      def process(node)
        return Loofah::Scrubber::CONTINUE if node.text? || node.cdata? || node.comment? || node.document? || node.fragment?

        unless ALLOWED_TAGS.include?(node.name)
          record_error(tag: node.name, line: node.line, reason: "disallowed tag")
          node.remove
          return Loofah::Scrubber::STOP
        end

        case node.name
        when "a"      then sanitize_anchor(node)
        when "img"    then sanitize_img(node)
        when "video", "audio", "source" then sanitize_media(node)
        when "link"   then sanitize_link_tag(node)
        when "use"    then sanitize_use(node)
        end

        scrub_attributes!(node)
        Loofah::Scrubber::CONTINUE
      end

      def scrub_attributes!(node)
        allowed = (GLOBAL_ATTRS + (PER_TAG_ATTRS[node.name] || [])).map(&:downcase)
        node.attribute_nodes.each do |attr|
          name = attr.name.downcase
          next if allowed.include?(name)
          next if data_attr_allowed?(name)
          record_error(tag: node.name, attr: name, line: node.line, reason: "disallowed attribute")
          node.remove_attribute(name)
        end
      end

      def data_attr_allowed?(name)
        return false unless name.start_with?("data-")
        DATA_ATTR_ALLOWLIST.include?(name)
      end

      def sanitize_anchor(node)
        href = node["href"]
        if href.present? && !http_scheme?(href)
          record_error(tag: "a", attr: "href", line: node.line, reason: "disallowed href scheme")
          node.remove_attribute("href")
        end
        if node["target"].to_s.downcase == "_blank"
          existing = node["rel"].to_s.split
          forced = (existing | %w[noopener noreferrer]).join(" ")
          node["rel"] = forced
        end
      end

      def sanitize_img(node)
        src = node["src"]
        return if src.blank?
        if http_scheme?(src) || src =~ IMG_DATA_URL
          # ok
        else
          record_error(tag: "img", attr: "src", line: node.line, reason: "disallowed src scheme")
          node.remove_attribute("src")
        end
      end

      def sanitize_media(node)
        src = node["src"]
        return if src.blank?
        unless http_scheme?(src)
          record_error(tag: node.name, attr: "src", line: node.line, reason: "disallowed src scheme")
          node.remove_attribute("src")
        end
      end

      def sanitize_link_tag(node)
        rel = node["rel"].to_s.downcase
        href = node["href"].to_s
        unless rel == "stylesheet" && font_link_allowed?(href)
          record_error(tag: "link", line: node.line, reason: "link rel=stylesheet only allowed for trusted font hosts")
          node.remove
        end
      end

      def sanitize_use(node)
        href = node["href"] || node["xlink:href"]
        if href.blank? || !href.start_with?("#")
          record_error(tag: "use", attr: "href", line: node.line, reason: "use must reference a fragment id")
          node.remove
        end
      end

      def http_scheme?(url)
        uri = parse_uri(url)
        return false if uri.nil?
        scheme = uri.scheme.to_s.downcase
        HTTP_SCHEMES.include?(scheme)
      end

      def font_link_allowed?(url)
        uri = parse_uri(url)
        return false if uri.nil?
        return false unless HTTP_SCHEMES.include?(uri.scheme.to_s.downcase)
        host = uri.host.to_s.downcase
        return true if FONT_HOST_ALLOWLIST.include?(host)
        prefix = FONT_PATH_PREFIXES[host]
        return false if prefix.nil?
        uri.path.to_s.start_with?(prefix)
      end

      def parse_uri(url)
        Addressable::URI.parse(url)
      rescue Addressable::URI::InvalidURIError, ArgumentError
        nil
      end

      def record_error(tag:, line:, reason:, attr: nil)
        @errors << { tag:, attr:, line:, reason: }
      end
  end
end
