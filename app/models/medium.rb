class Medium < ActiveRecord::Base
  include Content
  include Content::Attributed

  has_one :image_info, inverse_of: :image

  enum subclass: [ :image, :video, :sound ]
  enum format: [ :jpg, :youtube, :flash, :vimeo, :mp3, :ogg, :wav ]

  scope :images, -> { where(subclass: :image) }
  scope :videos, -> { where(subclass: :video) }
  scope :sounds, -> { where(subclass: :sound) }

  # TODO: we will have our own media server with more intelligent names:
  def original_size_url
    base_url + "_original.jpg"
  end

  def large_size_url
    base_url + "_580_360.jpg"
  end

  def medium_icon_url
    base_url + "_130_130.jpg"
  end
  alias_method :collect_with_icon, :medium_icon_url
  alias_method :icon, :medium_icon_url

  def medium_size_url
    base_url + "_260_190.jpg"
  end

  # Drat. :S
  def name(language = nil)
    self[:name]
  end

  def small_size_url
    base_url + "_98_68.jpg"
  end

  def small_icon_url
    base_url + "_88_88.jpg"
  end
end
