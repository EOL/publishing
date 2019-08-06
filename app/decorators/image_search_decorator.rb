class ImageSearchDecorator < MediumSearchDecorator
  decorates :medium

  def type
    :images
  end

  def total_results
    object.response["hits"]["total"]
  end
end
