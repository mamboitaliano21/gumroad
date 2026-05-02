# frozen_string_literal: true

require "spec_helper"

describe Pages::HtmlScrubber do
  def scrub(html, mode: :strict)
    described_class.call(html, mode:)
  end

  describe "negative XSS corpus (strict mode)" do
    {
      "script tag" => "<script>alert(1)</script>",
      "img onerror" => "<img src=x onerror=alert(1)>",
      "javascript: href" => "<a href=\"javascript:alert(1)\">x</a>",
      "iframe" => "<iframe src=\"https://evil.com\"></iframe>",
      "style tag" => "<style>body{background:red}</style>",
      "form input" => "<form action=\"/x\"><input name=\"x\"></form>",
      "inline style attribute" => "<div style=\"background:url(javascript:alert(1))\">x</div>",
      "svg onload" => "<svg onload=\"alert(1)\"></svg>",
      "svg containing script" => "<svg><script>alert(1)</script></svg>",
      "svg foreignObject" => "<svg><foreignObject><body><script>alert(1)</script></body></foreignObject></svg>",
      "math element" => "<math><mi>x</mi></math>",
      "details element" => "<details><summary>x</summary></details>",
      "template element" => "<template><script>alert(1)</script></template>",
      "embed" => "<embed src=\"https://evil.com\">",
      "object" => "<object data=\"https://evil.com\"></object>",
      "meta refresh" => "<meta http-equiv=\"refresh\" content=\"0; url=https://evil.com\">",
      "base tag" => "<base href=\"https://evil.com\">",
      "untrusted stylesheet link" => "<link rel=\"stylesheet\" href=\"https://evil.com/x.css\">",
      "data text/html href" => "<a href=\"data:text/html,<script>alert(1)</script>\">x</a>",
      "vbscript href" => "<a href=\"vbscript:msgbox(1)\">x</a>",
      "use external href" => "<svg><use href=\"https://evil.com/x.svg#a\"/></svg>",
      "srcdoc on iframe" => "<iframe srcdoc=\"<script>alert(1)</script>\"></iframe>",
      "formaction smuggle" => "<button formaction=\"javascript:alert(1)\">x</button>",
    }.each do |name, html|
      it "strips #{name}" do
        result = scrub(html)
        sanitized = result[:html]
        expect(sanitized).not_to include("alert(1)")
        expect(sanitized).not_to include("<script")
        expect(sanitized).not_to include("onerror")
        expect(sanitized).not_to include("onload")
        expect(sanitized).not_to include("javascript:")
        expect(sanitized).not_to include("vbscript:")
        expect(sanitized).not_to include("<form")
        expect(sanitized).not_to include("<iframe")
        expect(sanitized).not_to include("<style")
        expect(sanitized).not_to include("<embed")
        expect(sanitized).not_to include("<object")
        expect(sanitized).not_to include("<meta")
        expect(sanitized).not_to include("<base")
        expect(sanitized).not_to include("foreignObject")
        expect(result[:errors]).not_to be_empty
      end
    end

    it "strips mutation-XSS (noscript title smuggle)" do
      payload = '<noscript><p title="</noscript><img src=x onerror=alert(1)>"></noscript>'
      result = scrub(payload)
      expect(result[:html]).not_to include("onerror")
      expect(result[:html]).not_to include("alert(1)")
    end

    it "strips bg-[url(javascript:...)] inline-style smuggles" do
      payload = '<div class="bg-[url(javascript:alert(1))]" style="background:url(javascript:alert(1))">x</div>'
      result = scrub(payload)
      expect(result[:html]).not_to include("style=")
      expect(result[:html]).to include("class=")
    end
  end

  describe "positive corpus (strict mode)" do
    [
      "<section><h1>Hello</h1><p>world</p></section>",
      "<article><header><h2>Title</h2></header><p>Body</p><footer>End</footer></article>",
      "<ul><li>one</li><li>two</li></ul>",
      "<table><thead><tr><th>name</th></tr></thead><tbody><tr><td>x</td></tr></tbody></table>",
      "<pre><code>print(1)</code></pre>",
      "<blockquote cite=\"https://example.com\">quoted</blockquote>",
      "<svg viewBox=\"0 0 24 24\"><path d=\"M0 0H24V24H0Z\" fill=\"red\"/></svg>",
      "<svg><use href=\"#icon-buy\"/></svg>",
      "<img src=\"https://example.com/x.png\" alt=\"x\" loading=\"lazy\"/>",
      "<picture><source srcset=\"https://example.com/x.webp\" type=\"image/webp\"/><img src=\"https://example.com/x.png\" alt=\"x\"/></picture>",
      '<a class="gumroad-button bg-black text-white px-8 py-4" href="https://gumroad.com/l/abc" data-gumroad-overlay-checkout="true">Buy</a>',
      '<div class="gumroad-product-embed" data-gumroad-product-id="abc123"></div>',
      '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">',
      '<link rel="stylesheet" href="https://fonts.bunny.net/css?family=inter">',
      '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fontsource/inter/index.css">',
      '<div class="bg-[#ff0000] rotate-[3deg] text-[180px]">brutalist</div>',
    ].each do |html|
      it "preserves #{html.first(80).tr("\n", " ")}" do
        result = scrub(html)
        expect(result[:errors]).to be_empty, "unexpected errors: #{result[:errors].inspect}"
      end
    end

    it "preserves Tailwind class names verbatim including arbitrary values" do
      result = scrub('<div class="border-[8px] border-black font-mono bg-yellow-300">x</div>')
      expect(result[:html]).to include("border-[8px]")
      expect(result[:html]).to include("bg-yellow-300")
    end

    it "preserves the gumroad widget classes and data attributes" do
      payload = <<~HTML
        <a class="gumroad-button" href="https://gumroad.com/l/abc" data-gumroad-overlay-checkout="true">Buy</a>
        <div class="gumroad-product-embed" data-gumroad-product-id="def"></div>
      HTML
      result = scrub(payload)
      expect(result[:errors]).to be_empty
      expect(result[:html]).to include("gumroad-button")
      expect(result[:html]).to include("gumroad-product-embed")
      expect(result[:html]).to include("data-gumroad-overlay-checkout=\"true\"")
      expect(result[:html]).to include("data-gumroad-product-id=\"def\"")
    end

    it "forces rel=noopener noreferrer on target=_blank anchors" do
      result = scrub('<a href="https://example.com" target="_blank">x</a>')
      expect(result[:html]).to include('rel="noopener noreferrer"')
    end
  end

  describe "error reporting" do
    it "returns one error per stripped tag with line numbers" do
      payload = "<p>ok</p>\n<script>bad()</script>"
      result = scrub(payload)
      expect(result[:errors]).to include(
        a_hash_including(tag: "script", reason: "disallowed tag", line: 2)
      )
    end

    it "surfaces stripped attributes" do
      payload = '<div onclick="alert(1)">x</div>'
      result = scrub(payload)
      expect(result[:errors]).to include(
        a_hash_including(tag: "div", attr: "onclick", reason: "disallowed attribute")
      )
    end

    it "lossy mode never raises and still returns sanitized output" do
      payload = "<script>alert(1)</script><p>kept</p>"
      result = scrub(payload, mode: :lossy)
      expect(result[:html]).to include("kept")
      expect(result[:html]).not_to include("alert")
    end
  end

  describe "data:image/* URLs" do
    it "permits inline image data URLs" do
      payload = '<img src="data:image/png;base64,iVBORw0KGgo=" alt="x"/>'
      result = scrub(payload)
      expect(result[:html]).to include("data:image/png;base64")
      expect(result[:errors]).to be_empty
    end

    it "rejects non-image data URLs on img" do
      payload = '<img src="data:text/html,<script>alert(1)</script>"/>'
      result = scrub(payload)
      expect(result[:html]).not_to include("data:text/html")
    end
  end
end
