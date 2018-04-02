class VideoSearchDecorator < MediumSearchDecorator
  decorates :medium

  def type
    :videos
  end 
end
