class MediumSearchDecorator < SearchResultDecorator
  def icon
    if object.respond_to?(:medium_icon_url)
      object.medium_icon_url
    else
      nil 
    end
  end

  def fa_icon
    "file-text-o"
  end

  def title
    name = object.try(:search_highlights).try(:[], :name) || object.name
    type_str = type.to_s.singularize

    if !name.blank?
      I18n.t("search_results.medium_title_#{type_str}_html", :title => name)
    else
      I18n.t("search_results.medium_#{type_str}")
    end
  end

  def content
    object.try(:search_highlights).try(:[], :owner) || object.owner
  end

  def hierarchy
    nil
  end
end

