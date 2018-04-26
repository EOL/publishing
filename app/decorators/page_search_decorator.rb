class PageSearchDecorator < SearchResultDecorator
  include PageDecoratorHelper

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

  def page_id
    object.id
  end

  def top_resources
    [
      ["media", object.media_count],
      ["data", object.data_count],
      ["articles", object.articles_count],
    ].select { |x| x[1] > 0 }
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
