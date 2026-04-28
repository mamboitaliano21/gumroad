# frozen_string_literal: true

module EmbedHelpers
  def cleanup_embed_artifacts
    Dir.glob(Rails.root.join("public", "embed_spec_page_*.html")).each { |f| File.delete(f) }
  end

  # Wait for React to mount inside an embed iframe. Call this inside a
  # `within_frame` block before asserting on React-rendered elements like
  # radio buttons or number inputs. Without this, Capybara can check for
  # elements before React has hydrated the component tree, causing flakes.
  def wait_for_embed_react_mount
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script("document.readyState") == "complete"
    end
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script("document.querySelectorAll('button, input[type=radio], input[type=number]').length > 0")
    end
  end

  def create_embed_page(product, template_name: "embed_page.html.erb", url: nil, gumroad_params: nil, outbound: true, insert_anchor_tag: true, custom_domain_base_uri: nil, query_params: {})
    template = Rails.root.join("spec", "support", "fixtures", template_name)
    filename = Rails.root.join("public", "embed_spec_page_#{product.unique_permalink}.html")
    File.delete(filename) if File.exist?(filename)
    embed_html = ERB.new(File.read(template)).result_with_hash(
      unique_permalink: product.unique_permalink,
      outbound:,
      product:,
      url:,
      gumroad_params:,
      insert_anchor_tag:,
      js_nonce:,
      custom_domain_base_uri:
    )

    File.open(filename, "w") do |f|
      f.write(embed_html)
    end
    "/#{filename.basename}?#{query_params.to_param}"
  end
end
