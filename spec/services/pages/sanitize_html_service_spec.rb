# frozen_string_literal: true

require "spec_helper"

describe Pages::SanitizeHtmlService do
  def scrub(html)
    described_class.new(html).perform
  end

  describe "negative XSS corpus" do
    {
      "script tag" => "<script>alert(1)</script>",
      "img onerror" => "<img src=x onerror=alert(1)>",
      "javascript: href" => "<a href=\"javascript:alert(1)\">x</a>",
      "iframe" => "<iframe src=\"https://example.org\"></iframe>",
      "style tag" => "<style>body{background:red}</style>",
      "form input" => "<form action=\"/x\"><input name=\"x\"></form>",
      "inline style attribute" => "<div style=\"background:url(javascript:alert(1))\">x</div>",
      "svg onload" => "<svg onload=\"alert(1)\"></svg>",
      "svg containing script" => "<svg><script>alert(1)</script></svg>",
      "svg foreignObject" => "<svg><foreignObject><body><script>alert(1)</script></body></foreignObject></svg>",
      "math element" => "<math><mi>x</mi></math>",
      "details element" => "<details><summary>x</summary></details>",
      "template element" => "<template><script>alert(1)</script></template>",
      "embed" => "<embed src=\"https://example.org\">",
      "object" => "<object data=\"https://example.org\"></object>",
      "meta refresh" => "<meta http-equiv=\"refresh\" content=\"0; url=https://example.org\">",
      "base tag" => "<base href=\"https://example.org\">",
      "noscript element" => "<noscript><script>alert(1)</script></noscript>",
      "untrusted stylesheet link" => "<link rel=\"stylesheet\" href=\"https://example.org/x.css\">",
      "data text/html href" => "<a href=\"data:text/html,<script>alert(1)</script>\">x</a>",
      "vbscript href" => "<a href=\"vbscript:msgbox(1)\">x</a>",
      "use external href" => "<svg><use href=\"https://example.org/x.svg#a\"/></svg>",
      "srcdoc on iframe" => "<iframe srcdoc=\"<script>alert(1)</script>\"></iframe>",
      "formaction smuggle" => "<button formaction=\"javascript:alert(1)\">x</button>",
      "html comment with script" => "<!--<script>alert(1)</script>--><p>x</p>",
      "conditional comment" => "<!--[if IE]><script>alert(1)</script><![endif]--><p>x</p>",
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
        expect(sanitized).not_to include("<noscript")
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

    it "strips all data-* attributes" do
      payload = '<a class="btn" href="https://example.com" data-gumroad-overlay-checkout="true" data-gumroad-product-id="abc" data-anything="x">Buy</a>'
      result = scrub(payload)
      expect(result[:html]).not_to include("data-gumroad-overlay-checkout")
      expect(result[:html]).not_to include("data-gumroad-product-id")
      expect(result[:html]).not_to include("data-anything")
      expect(result[:html]).to include("class=\"btn\"")
      expect(result[:html]).to include("href=\"https://example.com\"")
      expect(result[:errors].map { |e| e[:attr] }).to include("data-gumroad-overlay-checkout", "data-gumroad-product-id", "data-anything")
    end
  end

  describe "positive corpus" do
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
      '<a class="btn bg-black text-white px-8 py-4" href="https://example.com/checkout?product=abc">Buy</a>',
      '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">',
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

    it "still returns sanitized output when content is fully stripped" do
      payload = "<script>alert(1)</script><p>kept</p>"
      result = scrub(payload)
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
