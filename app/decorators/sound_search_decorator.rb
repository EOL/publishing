class SoundSearchDecorator < MediumSearchDecorator
  decorates :medium

  def type
    :sounds
  end 
end
