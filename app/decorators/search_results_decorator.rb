class SearchResultsDecorator < Draper::CollectionDecorator
  delegate :current_page, :total_pages, :limit_value, :entry_name, :total_count, :offset_value, :last_page?

  def type
    decorated_collection.first&.type
  end

  def fa_icon
    decorated_collection.first&.fa_icon
  end
end
