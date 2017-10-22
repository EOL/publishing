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
      total += r.length
    end
    total
  end

  def medium_name(medium)
    medium.try(:search_highlights).try(:[], :name) || medium.name
  end

private
  def page_family_ancestor_name(page)
    ancestors = page.native_node.try(:ancestors)

    return nil unless ancestors

    ancestor = ancestors.detect do |a|
      Rank.guess_treat_as(a.rank.name) === :r_family
    end
    ancestor ? ancestor.name : nil
  end
end
