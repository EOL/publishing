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
    addclass = options.delete(:button_class) || ""
    haml_tag("button.ui.labeled.small.icon.basic.button.uk-margin-small-bottom#{addclass}") do
      haml_tag("i.#{icon}.icon")
      haml_concat(link_to(label, url, options))
    end
  end

  def emphasize_match(name, match)
    return "" if name.nil?
    return name if match.nil?
    return name.html_safe unless name =~ /(#{Regexp.escape(match)})/i
    highlight(excerpt(name, match, separator: " ", radius: 5), match)
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
end
