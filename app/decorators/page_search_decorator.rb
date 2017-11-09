class PageSearchDecorator < SearchResultDecorator
  decorates :page
  delegate :icon
  
  def type
    :pages
  end

  def fa_icon
    "picture-o"
  end

  def title
    object.try(:search_highlights).try(:[], :preferred_vernacular_strings) || object.name
  end

  def content
    object.try(:search_highlights).try(:[], :scientific_name) || object.scientific_name
  end

  def hierarchy
    ancestor_name = family_ancestor_name()
    common_name = title

    ancestor_name ? "#{ancestor_name} … / #{common_name}" : common_name
  end
  
private
  def family_ancestor_name()
    ancestors = object.native_node.try(:ancestors)

    return nil unless ancestors

    ancestor = ancestors.detect do |a|
      Rank.guess_treat_as(a.rank.name) === :r_family
    end
    ancestor ? ancestor.name : nil
  end
end
