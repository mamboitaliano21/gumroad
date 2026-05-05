# frozen_string_literal: true

module PagesHelper
  def page_srcdoc(page)
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>" \
      "#{page.compiled_css}</style></head><body>#{page.sanitized_html}</body></html>"
  end
end
