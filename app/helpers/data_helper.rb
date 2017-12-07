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
    show_definition(data[:units]) if data[:units]
    show_definition(data[:predicate]) if data[:predicate]
    show_definition(data[:object_term]) if data[:object_term]
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

  def show_data_value(data)
    value = t(:data_missing, keys: data.keys.join(", "))
    if (target_id = data[:object_page_id] || data[:target_page_id])
      if defined?(@associations)
        target = @associations.find { |a| a.id == target_id }
        if target.nil?
          haml_concat "[page #{data[:object_page_id]} not imported]"
        else
          summarize(target, options = {})
        end
      else
        haml_concat "MISSING PAGE: "
        haml_concat value
      end
    elsif data[:object_term] && data[:object_term][:name]
      value = data[:object_term][:name]
      haml_concat(link_to(value, term_path(uri: data[:object_term][:uri], object: true)))
    elsif val = data[:measurement] || data[:value_measurement]
      value = val.to_s + " "
      value += data[:units][:name] if data[:units] && data[:units][:name]
      haml_concat(value.html_safe)
    elsif val = data[:literal] || data[:value_literal]
      haml_concat unlink(val).html_safe
    else
      haml_concat "CORRUPTED VALUE:"
      haml_concat value
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

  def show_source(src)
    haml_tag(:div, class: "ui secondary segment") do
      haml_concat I18n.t(:data_source)
    end
    haml_tag(:div, class: "ui tertiary segment") do
      haml_concat unlink(src).html_safe
    end
  end

  def show_source_segment(data)
    # TODO: make this a proper link
    haml_tag(:div, class: "ui attached segment table-source uk-width-1-5 uk-visible@m eol-padding-tiny") do
      if @resources && resource = @resources[data[:resource_id]] # rubocop:disable Lint/AssignmentInCondition
        haml_tag("div.uk-overflow-auto") do
          haml_concat(link_to(resource.name, "#", title: resource.name,
            data: { toggle: "tooltip", placement: "left" } ))
        end
      else
        haml_concat(I18n.t(:resource_missing))
      end
    end
  end

  def show_data_page_icon(page)
    if image = page.medium # rubocop:disable Lint/AssignmentInCondition
      haml_concat(link_to(image_tag(image.small_icon_url,
        alt: page.scientific_name.html_safe, size: "44x44"), page))
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
    [data[:statistical_method], data[:sex], data[:lifestage]].compact.each do |type|
      haml_tag(:div, type, class: "data_type uk-text-muted uk-text-small uk-text-left")
    end
  end

  def obj_term_options(pred_uri)
    options = [["----", nil]]

    if (!pred_uri.blank?)
      TraitBank.obj_terms_for_pred(pred_uri).each do |term|
        options.push([term[:name], term[:uri]])
      end
    end

    options
  end
end
