class PageDecorator < Draper::Decorator
  delegate_all

  def summary_hierarchy
    h.summary_hierarchy(object, true)
  end

  def full_hierarchy
    h.full_hierarchy(object, true)
  end

  def cached_summary
    Rails.cache.fetch("pages/#{id}/brief_summary") do
      BriefSummary.new(object, h).english # TODO: Someday we need to I18n this. ...somehow.
    end
  end

  def associated_pages=(val)
    @associated_pages = val
  end

  def associated_page(id)
    raise TypeError.new("associated_pages not set") unless @associated_pages
    @associated_pages[id]
  end
end

