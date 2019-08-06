class VideoSearchDecorator < MediumSearchDecorator
  decorates :medium

  def type
    :videos
  end

  def total_results
    object.response["hits"]["total"]
  end
end
