module ApplicationHelper
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

  def emphasize_match(name, match)
    return name.html_safe unless name =~ /(#{match})/i
    highlight(excerpt(name, match, separator: " ", radius: 5), match)
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
end
