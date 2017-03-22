module ApplicationHelper
  def first_cap(string)
    string.slice(0,1).capitalize + string.slice(1..-1)
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

  def emphasize_match(name, match)
    return name.html_safe unless name =~ /(#{match})/i
    highlight(excerpt(name, match, separator: " ", radius: 5), match)
  end

  def icon(which)
    haml_tag("span", uk: { icon: "icon: #{which}" })
  end
end
