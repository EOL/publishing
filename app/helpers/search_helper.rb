module SearchHelper
  def page_common_name(page)
    page.try(:search_highlights).try(:[], :preferred_vernacular_strings) || page.name
  end

  def page_sci_name(page)
    page.try(:search_highlights).try(:[], :scientific_name) || page.scientific_name
  end

  def hierarchy_str(page)
    ancestor_name = page_family_ancestor_name(page)
    common_name = page_common_name(page)

    ancestor_name ? "#{ancestor_name} … / #{common_name}" : common_name
  end

  def result_total(results)
    total = 0
    results.each do |r|
      total += r.total_count if r
    end
    total
  end

  def medium_name(medium)
    medium.try(:search_highlights).try(:[], :name) || medium.name
  end

  def medium_title(medium)
    title = medium_name(medium)
    type = medium_type(medium)

    if !title.blank?
      if type
        I18n.t("search_results.medium_title_#{type}_html", :title => title)
      else
        title
      end
    else
      if type
        I18n.t("search_results.medium_#{type}")
      else
        I18n.t("search_results.no_title")
      end
    end


  end


private
  def medium_type(medium)
    return "article" if medium.is_a?(Article)
    return nil if !medium.is_a?(Medium)
    return "image" if medium.image?
    return "video" if medium.video?
    return "sound" if medium.sound?
    return "map" if medium.map? || medium.js_map?
  end

  def page_family_ancestor_name(page)
    ancestors = page.native_node.try(:ancestors)

    return nil unless ancestors

    ancestor = ancestors.detect do |a|
      Rank.guess_treat_as(a.rank.name) === :r_family
    end
    ancestor ? ancestor.name : nil
  end
end
