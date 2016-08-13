class Medium < ActiveRecord::Base
  include Content
  include Content::Attributed

  has_one :image_info, inverse_of: :image

  enum subclass: [ :image, :video, :sound ]
  enum format: [ :jpg, :youtube, :flash, :vimeo, :mp3, :ogg, :wav ]

  scope :images, -> { where(subclass: :image) }
  scope :videos, -> { where(subclass: :video) }
  scope :sounds, -> { where(subclass: :sound) }
end
