# NOTE that you use the show_* methods with a - not a = because it's writing
# to the stream directly, NOT building an output for you to show...
module DataHelper
  def metadata_container(data)
    haml_tag(:div, id: data[:id], class: "ui segments meta_data", style: "display: none;")
  end

  def show_metadata(data)
    return if data.nil?
    return unless data[:meta] ||
      data[:source] ||
      data[:object_term] ||
      data[:units]
    if data[:metadata]
      data[:metadata].each do |datum|
        show_meta_data(datum)
      end
    end
    show_definition(data[:predicate]) if data[:predicate]
    show_definition(data[:object_term]) if data[:object_term]
    show_definition(data[:units]) if data[:units]
    show_modifier(:sex_term, data[:sex_term]) if data[:sex_term]
    show_modifier(:lifestage_term, data[:lifestage_term]) if data[:lifestage_term]
    show_modifier(:statistical_method_term, data[:statistical_method_term]) if data[:statistical_method_term]
    show_source(data[:source]) if data[:source]
  end

  def show_meta_data(datum)
    haml_tag(:div, class: "ui secondary segment") do
      haml_concat datum[:predicate][:name]
      if datum[:predicate][:uri]
        haml_tag(:br)
        haml_tag(:div, datum[:predicate][:uri], class: "data_type uk-text-muted eol-text-tiny")
      end
    end
    haml_tag(:div, class: "ui tertiary segment") do
      show_data_value(datum)
    end
  end

  def build_associations(page)
    @associations =
      begin
        ids = page.data.map { |t| t[:object_page_id] }.compact.sort.uniq
        Page.where(id: ids).
          includes(:medium, :preferred_vernaculars, native_node: [:rank])
      end
  end

  def data_value(data)
    parts = []
    value = t(:data_missing, keys: data.keys.join(", "))
    if (target_id = data[:object_page_id])
      if defined?(@associations)
        target = @associations.find { |a| a.id == target_id }
        if target.nil?
          # TODO: log something?
        else
          parts << name_for_page(target)
        end
      else
        Rails.logger("**** INEFFICIENT! Loading association for trait #{data[:eol_pk]}")
        parts << name_for_page(Page.find(data[:object_page_id]))
      end
    elsif data[:object_term] && data[:object_term][:name]
      value = data[:object_term][:name]
      parts << value
    elsif val = data[:measurement] || data[:value_measurement]
      parts << val.to_s
      parts << data[:units][:name] if data[:units] && data[:units][:name]
    elsif val = data[:literal]
      parts << unlink(val).html_safe
    else
      parts << "CORRUPTED VALUE:"
      parts <<  value
    end

    parts.join(" ")
  end

  def show_data_value(data)
    value = data_value(data)

    haml_tag_if(data[:object_term], ".a") do
      haml_concat value.html_safe # Traits allow HTML.
    end
  end

  def modifier_txt(data)
    modifiers = [ data[:sex_term], data[:lifestage_term], data[:statistical_method_term] ].reject { |x| x.nil? }

    if modifiers.any?
      separated_list(modifiers)
    else
      nil
    end
  end


  def show_definition(uri)
    return unless uri && uri[:definition]
    haml_tag(:div, I18n.t(:data_definition, data: uri[:name]), class: "ui secondary segment")
    haml_tag(:div, class: "ui tertiary segment") do
      haml_tag(:a, uri[:uri], href: uri[:uri], class: "uri_defn")
      haml_tag(:br)
      if uri[:definition].empty?
        haml_concat(I18n.t(:data_unit_definition_blank))
      else
        haml_concat(uri[:definition].html_safe)
      end
    end
  end

  def show_modifier(type, value)
    haml_tag(:div, I18n.t("data.modifier.#{type}"), class: "ui secondary segment")
    if value =~ URI::ABS_URI
      term = TraitBank.term(value)
      value = term[:name] if term && term.key?(:name)
    end
    haml_tag(:div, value, class: "ui tertiary segment")
  end

  def show_source_segment(data)
    if @resources && resource = @resources[data[:resource_id]] # rubocop:disable Lint/AssignmentInCondition
      link_txt = resource.name.blank? ? resource_path(resource) : resource.name
      link_to(link_txt, resource)
    else
      I18n.t(:resource_missing)
    end
  end

  def show_data_page_icon(page)
    if image = page.medium # rubocop:disable Lint/AssignmentInCondition
      haml_concat(link_to(image_tag(image.small_icon_url,
        # TODO: restore this or find some placeholder images:
        # alt: page.scientific_name.html_safe, size: "44x44"), page))
        alt: '', size: "44x44"), page))
    end
  end

  def show_data_page_name(page)
    haml_tag(:div, class: "names d-inline") do
      if page.name && page.name != page.scientific_name
        haml_concat(link_to(page.name.titlecase, page, class: "primary-name"))
        haml_tag(:br)
        haml_concat(link_to(page.scientific_name.html_safe, page, class: "secondary-name"))
      else
        haml_concat(link_to(page.scientific_name.html_safe, page, class: "primary-name"))
      end
    end
  end

  def show_data_modifiers(data)
    [data[:statistical_method_term], data[:sex_term], data[:lifestage_term]].compact.each do |type|
      haml_tag(:div, type[:name], class: "data_type uk-text-muted uk-text-small uk-text-left")
    end
  end
end
