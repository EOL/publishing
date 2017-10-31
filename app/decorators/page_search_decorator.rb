class PageSearchDecorator < Draper::Decorator
  decorates :page
  delegate :persisted?, :icon

  def self.collection_decorator_class
    KaminariDecorator
  end
  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
  
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

  def misc_info
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
