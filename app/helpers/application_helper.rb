module ApplicationHelper
  def first_cap(string)
    string.slice(0,1).capitalize + string.slice(1..-1)
  end

  def languages_hash
    {
      en: "English",
      fr: "Francais",
      de: "Deutsch",
      ru: "Pусский",
      es: "Español"
    }
  end

  def cms_menu
    menu_items = Refinery::Menu.new(Refinery::Page.in_menu)

    Refinery::Pages::MenuPresenter.new(menu_items, self).tap do |presenter|
      presenter.dom_id = "cms_menu"
      presenter.css = "ui simple dropdown item uk-visible@m"
      presenter.menu_tag = :div
      presenter.list_tag = :div
      presenter.list_tag_css = "uk-list uk-padding-small uk-dropdown uk-dropdown-bottom-left"
      presenter.list_item_tag = :li
      presenter.selected_css = "active"
      # presenter.link_tag_css = "item"
    end
  end

  def term_search_name(options = nil) # rubocop:disable Metrics/CyclomaticComplexity
    if options
      set_term_search_instance_variables_from_options(options)
    end
    string =
      if @species_list
        "All pages matching"
      else
        "All data records for"
      end
    if @object && @and_predicate
      string += " #{@and_predicate[:name]}"
    elsif @object
      string += " any attribute"
    else
      string += " #{@term[:name]}"
      string += " and #{@and_predicate[:name]}" if @and_predicate
    end
    if @object
      string += %Q{ with #{@and_object ? " values" : " value"} "#{@term[:name]}"}
      if @and_object
        string += %Q{ #{@species_list ? "and" : "or"} "#{@and_object[:name]}"}
      end
    elsif @and_object
      string += " with value #{@and_object[:name]}"
    end
    if @clade
      string += ", for #{@clade.name}"
    end
    string
  end

  def link_to_page_by_name(page)
    link_to(name_for_page(page), page)
  end

  def name_for_page(page)
    return "[MISSING]" if page.nil?
    if page.scientific_name == page.name
      page.scientific_name.html_safe
    else
      "#{page.scientific_name} (#{page.name})".html_safe
    end
  end

  def link_to_page_canonical(page)
    link_to(name_for_page_canonical(page), page)
  end

  def name_for_page_canonical(page)
    if page.scientific_name == page.name
      page.canonical.html_safe
    else
      "#{page.canonical} (#{page.name})".html_safe
    end
  end

  # I kinda hate that I'm using instance variables, here, but it makes it much
  # simpler for the views that already have them.
  def set_term_search_instance_variables_from_options(options)
    @species_list = options[:species_list]
    @and_object = options[:object]
    @and_predicate = options[:predicate]
    # NOTE THAT YOU CANNOT HAVE TWO PREDICATES AND TWO OBJECTS!!!! (It's not
    # allowed in the UI, so I'm not accounting for it in the code)
    if @and_object.is_a?(Array)
      @term = TraitBank.term_as_hash(@and_object.first)
      @and_object = @and_object.size == 1 ? nil :
        TraitBank.term_as_hash(@and_object.last)

      @object = true
    elsif @and_predicate.is_a?(Array)
      @term = TraitBank.term_as_hash(@and_predicate.first)
      @and_predicate = @and_predicate.size == 1 ? nil :
        TraitBank.term_as_hash(@and_predicate.last)
      @object = false
    else
      # TODO: the whole "object" flag is LAME. Remove it entirely!
      @object = options[:object] && ! options[:predicate]
      if options[:predicate] && options[:predicate]
        @term = TraitBank.term_as_hash(options[:predicate])
        @and_predicate = nil
        @and_object = TraitBank.term_as_hash(options[:object])
      elsif options[:predicate]
        @term = TraitBank.term_as_hash(options[:predicate])
        @and_predicate = nil
        @and_object = nil
      else
        @term = TraitBank.term_as_hash(options[:object])
        @and_predicate = nil
        @and_object = nil
      end
    end
    @clade = options[:clade]
  end

  def resource_error_messages(resource)
    return "" if resource.errors.empty?

    messages = resource.errors.full_messages.map { |msg| content_tag(:li, msg) }.join
    sentence = I18n.t("errors.messages.not_saved",
                      count: resource.errors.count,
                      resource: resource.class.model_name.human.downcase)

    html = <<-HTML
    <div id="error_explanation">
      <h2>#{sentence}</h2>
      <ul>#{messages}</ul>
    </div>
    HTML

    html.html_safe
  end

  def params_less(*keys)
    params_dup = params.dup
    # These are NEVER required:
    params_dup.delete(:controller)
    params_dup.delete(:action)
    keys.each { |k| params_dup.delete(k) }
    params_dup
  end

  def basic_button(icon, label, url, options = {})
    addclass = options.delete(:button_class) || nil
    nomargin = options.delete(:no_margin) || false
    classes = %w(ui labeled small icon basic button)
    classes << "uk-margin-small-bottom" unless nomargin
    classes << addclass if addclass
    haml_tag("button.#{classes.join(".")}") do
      haml_tag("i.#{icon}.icon")
      haml_concat(link_to(label, url, options))
    end
  end

  def emphasize_match(name, match)
    return "" if name.nil?
    return name.html_safe unless !match.nil? && name =~ /(#{Regexp.escape(match)})/i
    highlight(excerpt(name, match, separator: " ", radius: 5), match).html_safe
  end

  def icon(which)
    haml_tag("span", uk: { icon: "icon: #{which}" })
  end

  def get_last_modified_date
    last_modified_part = []
    page_parts = Refinery::PagePart.where(refinery_page_id: @page.id).pluck(:id)
    page_parts.each do |id|
      last_modified_part << Refinery::PagePart::Translation.where(refinery_page_part_id: id , locale: Refinery::I18n.default_frontend_locale).pluck(:updated_at)
    end
    last_modified_part.max.join(' ')
  end

  def set_page_date(date)
    Refinery::Page.where(show_date: true)
  end

  def hide_params_in_form(except = [])
    except += %w(controller action utf8)
    params.each do |param, val|
      next if except.include?(param)
      haml_concat hidden_field_tag(param, val)
    end
  end

  # different checks for dev and prod
  def asset_exists?(path)
    if Rails.configuration.assets.compile
      Rails.application.precompiled_assets.include? path
    else
      Rails.application.assets_manifest.assets[path].present?
    end
  end

  def search_highlight(page, field, attribute = nil)
    highlight = page.try(:search_highlights).try(:[], field)
    highlight ||= page.try(:search_highlights).try(field)
    if highlight
      CGI.unescapeHTML(highlight).html_safe
    elsif attribute.nil?
      nil # They don't want us to look at the page for a default.
    else
      page.send(attribute).html_safe
    end
  end
end
