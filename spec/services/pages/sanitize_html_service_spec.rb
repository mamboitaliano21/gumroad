# frozen_string_literal: true

require "spec_helper"

describe Pages::SanitizeHtmlService do
  def sanitize(html)
    described_class.new(html).perform[:html]
  end

  it "strips script tags" do
    expect(sanitize("<div>ok<script>alert(1)</script></div>")).to include("ok")
    expect(sanitize("<div>ok<script>alert(1)</script></div>")).not_to include("<script")
  end

  it "strips form tags" do
    expect(sanitize("<form action=\"x\"><input></form>")).not_to include("<form")
  end

  it "strips iframe tags" do
    expect(sanitize("<iframe src=\"javascript:1\"></iframe>")).not_to include("<iframe")
  end

  it "strips style tags" do
    expect(sanitize("<style>body{x:expression(alert(1))}</style><p>ok</p>")).not_to include("<style")
  end

  it "strips inline event handlers" do
    expect(sanitize("<div onclick=\"alert(1)\">x</div>")).not_to include("onclick")
  end

  it "strips javascript: hrefs on anchors" do
    out = sanitize("<a href=\"javascript:alert(1)\">x</a>")
    expect(out).not_to include("javascript:")
  end

  it "strips data: URIs in img src except whitelisted image MIME types" do
    out = sanitize("<img src=\"data:text/html,<script>alert(1)</script>\">")
    expect(out).not_to include("data:text/html")
  end

  it "permits relative anchor href" do
    out = sanitize("<a href=\"/checkout?product=abc\">Buy</a>")
    expect(out).to include("/checkout?product=abc")
  end

  it "forces noopener on target=_blank links" do
    out = sanitize("<a href=\"https://example.com\" target=\"_blank\">x</a>")
    expect(out).to include("noopener")
    expect(out).to include("noreferrer")
  end

  it "drops nested iframe attempts even with valid attributes" do
    out = sanitize("<div><iframe sandbox=\"\" src=\"https://example.com\"></iframe></div>")
    expect(out).not_to include("<iframe")
  end

  it "strips comments" do
    out = sanitize("<div>ok</div><!-- secret -->")
    expect(out).not_to include("secret")
  end
end
