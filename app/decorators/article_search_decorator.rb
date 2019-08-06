class ArticleSearchDecorator < MediumSearchDecorator
  decorates :article

  def type
    :articles
  end

  def total_results
    object.response["hits"]["total"]
  end
end
