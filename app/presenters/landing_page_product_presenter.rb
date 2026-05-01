# frozen_string_literal: true

class LandingPageProductPresenter
  def self.apply(props:, landing_page:)
    new(landing_page).apply(props)
  end

  def initialize(landing_page)
    @landing_page = landing_page
  end

  def apply(props)
    overrides = {}
    overrides[:name]                      = lp.name                  if lp.name.present?
    overrides[:description_html]          = lp.html_safe_description if lp.description.present?
    overrides[:summary]                   = lp.custom_summary        if lp.custom_summary.present?
    overrides[:attributes]                = override_attributes_for(props) if lp.custom_attributes.present?

    return props if overrides.empty?

    props.merge(product: props[:product].merge(overrides))
  end

  private
    def lp = @landing_page

    def override_attributes_for(props)
      file_info_attrs = (props[:product][:attributes] || []).reject { |a| product_custom_attribute_names.include?(a[:name]) }
      lp_attrs = lp.custom_attributes.filter_map do |attr|
        { name: attr["name"], value: attr["value"] } if attr["name"].present? || attr["value"].present?
      end
      lp_attrs + file_info_attrs
    end

    def product_custom_attribute_names
      lp.product.custom_attributes.filter_map { |a| a["name"].presence }
    end
end
