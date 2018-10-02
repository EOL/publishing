class PageDecorator < Draper::Decorator
  delegate_all

  def summary_hierarchy
    h.summary_hierarchy(object, true)
  end

  def full_hierarchy
    h.full_hierarchy(object, true)
  end

  def cached_summary
    Rails.cache.fetch("brief_summary/#{id}") do
      BriefSummary.new(object, h).english # TODO: Someday we need to I18n this. ...somehow.
    end
  end
end

