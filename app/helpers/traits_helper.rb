# NOTE that you use the show_* methods with a - not a = because it's writing
# to the stream directly, NOT building an output for you to show...
module TraitsHelper
  def metadata_container(trait)
    return unless trait[:meta] ||
      trait[:source] ||
      trait[:object_term] ||
      trait[:units]
    haml_tag(:div, class: "meta_trait", style: "display: none;")
  end

  def show_metadata(trait)
    return unless trait[:meta] ||
      trait[:source] ||
      trait[:object_term] ||
      trait[:units]
    haml_tag(:table) do
      if trait[:metadata]
        trait[:metadata].each do |meta_trait|
          show_meta_trait(meta_trait)
        end
      end
      show_definition(trait[:units])
      show_definition(trait[:object_term]) if trait[:object_term]
      show_source(trait[:source]) if trait[:source]
    end
  end

  def show_meta_trait(meta_trait)
    haml_tag :tr do
      haml_tag :th, meta_trait[:predicate][:name]
      haml_tag :td do
        show_trait_value(meta_trait)
      end
    end
  end

  # NOTE: yes, this is a long method. It *might* be worth breaking up, but I'm
  # not sure it would add to the clarity.
  def show_trait_value(trait)
    value = t(:trait_missing, keys: trait.keys.join(", "))
    if trait[:object_page_id] && defined?(@associations)
      target = @associations.find { |a| a.id == trait[:object_page_id] }
      show_trait_page_icon(target) if target.should_show_icon?
      summarize(target, options = {})
    elsif trait[:measurement]
      value = trait[:measurement].to_s + " "
      value += trait[:units][:name] if trait[:units] && trait[:units][:name]
      haml_concat(first_cap(value).html_safe)
    elsif trait[:object_term] && trait[:object_term][:name]
      value = trait[:object_term][:name]
      haml_concat(first_cap(value))
    elsif trait[:literal]
      haml_concat first_cap(unlink(trait[:literal])).html_safe
    else
      haml_concat "OOPS: "
      haml_concat value
    end
  end

  def show_definition(uri)
    return unless uri && uri[:definition]
    haml_tag(:tr) do
      haml_tag(:th, I18n.t(:trait_definition, trait: uri[:name]))
      haml_tag(:td) do
        haml_tag(:span, uri[:uri], class: "uri_defn")
        haml_tag(:br)
        if uri[:definition].empty?
          haml_concat(I18n.t(:trait_unit_definition_blank))
        else
          haml_concat(uri[:definition].html_safe)
        end
      end
    end
  end

  def show_source(src)
    haml_tag(:tr) do
      haml_tag(:th, I18n.t(:trait_source))
      haml_tag(:td, unlink(src))
    end
  end

  def show_source_col(trait)
    # TODO: make this a proper link
    haml_tag(:td, class: "table-source") do
      if @resources && resource = @resources[trait[:resource_id]]
        haml_tag("div.uk-overflow-auto") do
          haml_concat(link_to(resource.name, "#", title: resource.name,
            data: { toggle: "tooltip", placement: "left" } ))
        end
      else
        haml_concat(I18n.t(:resource_missing))
      end
    end
  end

  def show_trait_page_icon(page)
    if image = page.top_image
      haml_concat(link_to(image_tag(image.small_icon_url,
        alt: page.scientific_name.html_safe, size: "44x44"), page))
    end
  end

  def show_trait_page_name(page)
    haml_tag(:div, class: "names d-inline") do
      if page.name
        haml_concat(link_to(page.name.titlecase, page, class: "primary-name"))
        haml_tag(:br)
        haml_concat(link_to(page.scientific_name.html_safe, page, class: "secondary-name"))
      else
        haml_concat(link_to(page.scientific_name.html_safe, page, class: "primary-name"))
      end
    end
  end

  def show_trait_modifiers(trait)
    haml_tag(:br)
    [trait[:statistical_method], trait[:sex], trait[:lifestage]].compact.each do |type|
      haml_tag(:span, "(#{type})", class: "trait_type")
    end
  end
end
