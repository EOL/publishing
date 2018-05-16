class ImageSearchDecorator < MediumSearchDecorator
  decorates :medium

  def type
    :images
  end
end
