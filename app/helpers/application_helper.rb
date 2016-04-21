module ApplicationHelper
  def get_last_modified_date
    last_modified_part = []
    page_parts = Refinery::PagePart.where(refinery_page_id: @page.id).pluck(:id)
    page_parts.each do |id|
      last_modified_part << Refinery::PagePart::Translation.where(refinery_page_part_id: id , locale: Refinery::I18n.default_frontend_locale).pluck(:updated_at)
    end
    last_modified_part.max.join(' ')
  end
end
