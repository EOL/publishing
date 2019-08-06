class SoundSearchDecorator < MediumSearchDecorator
  decorates :medium

  def type
    :sounds
  end

  def total_results
    object.response["hits"]["total"]
  end
end
