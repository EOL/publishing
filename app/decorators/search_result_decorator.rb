class SearchResultDecorator < Draper::Decorator
  delegate :persisted?

  def self.collection_decorator_class
    SearchResultsDecorator
  end

  def hierarchy
    nil
  end

  def top_resources
    []
  end
end
