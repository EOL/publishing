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
    Rails.logger.warn "____ GIMMIE A TITLE!"
    object.try(:search_highlights).try(:[], :preferred_vernacular_strings) || object.name
  end

  def content
    Rails.logger.warn "____ GIMMIE YER CONTENT!"
    object.try(:search_highlights).try(:[], :scientific_name) || object.scientific_name
  end

  def page_id
    object.id
  end

  def top_resources
    [
      ["media", object.media_count],
      ["data", TraitBank.count_by_page(object.id)],
      ["articles", object.articles_count],
    ].select { |x| x[1] > 0 }
  end

  def hierarchy
    h.summary_hierarchy(object, false)
  end

private
#  def family_ancestor_name
#    ancestors = object.native_node.try(:ancestors)
#
#    return nil unless ancestors
#
#    ancestor = ancestors.detect do |a|
#      Rank.guess_treat_as(a.rank.name) === :r_family
#    end
#    ancestor ? ancestor.name : nil
#  end
end
