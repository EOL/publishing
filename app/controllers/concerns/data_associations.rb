module DataAssociations
  extend ActiveSupport::Concern

  def build_associations(data)
    @associations = 
      begin
        ids = data.map { |t| t[:object_page_id] }.compact.sort.uniq
        pages = Page.where(id: ids).
          includes(:medium, :preferred_vernaculars, native_node: [:rank])
        pages.collect { |p| [p.id, p] }.to_h
      end
  end
end
