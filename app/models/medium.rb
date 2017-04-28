class Medium < ActiveRecord::Base
  include Content
  include Content::Attributed

  # Yes, we store this in two places. First, we log who set the icon when:
  has_many :page_icons, inverse_of: :medium
  # And then we denormlize the latest so we can query it efficiently:
  has_many :pages, inverse_of: :medium

  has_one :image_info, inverse_of: :image

  enum subclass: [ :image, :video, :sound, :map, :js_map ]
  enum format: [ :jpg, :youtube, :flash, :vimeo, :mp3, :ogg, :wav ]

  scope :images, -> { where(subclass: :image) }
  scope :videos, -> { where(subclass: :video) }
  scope :sounds, -> { where(subclass: :sound) }

  searchable do
    text :name, :boost => 6.0
    text :description, :boost => 2.0
    text :resource_pk
    text :owner
  end

  # TODO: we will have our own media server with more intelligent names:
  def original_size_url
    base_url + "_orig.jpg"
  end

  def large_size_url
    base_url + "_580_360.jpg"
  end

  def medium_icon_url
    base_url + "_130_130.jpg"
  end
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

  def vitals
    [name, "#{license.name} #{owner.html_safe}"]
  end

  # TODO: spec these methods:
  def is_image?
    subclass == :image
  end

  def is_video?
    subclass == :video
  end

  def is_sound?
    subclass == :sound
  end

  def is_map?
    subclass == :map
  end

  def is_js_map?
    subclass == :js_map
  end
end
