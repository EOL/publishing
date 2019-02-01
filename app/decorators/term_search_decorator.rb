class TermSearchDecorator < SearchResultDecorator
  decorates :term_node
  delegate_all

  def type
    :terms
  end

  def title
    object.try(:search_highlights).try(:[], :name) || object.name
  end

  def content
    "#{object.uri}<br>#{object.definition}"
  end

  def icon
    nil
  end

  def hierarchy
    nil
  end

  def fa_icon
    "book-open"
  end
end
