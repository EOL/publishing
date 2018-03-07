class ArticleSearchDecorator < MediumSearchDecorator
  decorates :article

  def type
    :articles
  end 
end
