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

  def sci_names_by_status
    scientific_names.includes(:taxonomic_status).references(:taxonomic_status)
      .where("taxonomic_statuses.id != ?", TaxonomicStatus.unusable.id)
      .group_by do |n|
        h.t("scientific_name.status_title.#{n.taxonomic_status.name}")
      end
  end
end

