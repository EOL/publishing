class CollectedPage < ActiveRecord::Base
  belongs_to :page, inverse_of: :collected_pages
  belongs_to :collection, inverse_of: :collected_pages

  has_many :collected_pages_media, -> { order(position: :asc) },
    inverse_of: :collected_page
  has_many :media, through: :collected_pages_media
  has_and_belongs_to_many :articles, -> { order(position: :asc) }
  has_and_belongs_to_many :links, -> { order(position: :asc) }

  acts_as_list scope: :collection

  accepts_nested_attributes_for :collected_pages_media

  # For convenience, this is duck-typed from CollectionAssociation (q.v.)
  def item
    page
  end

  # NOTE: we could achieve this with delegation, but: meh. That's not as clear.
  def name
    page.name
  end

  def scientific_name_string
    page.scientific_name
  end

  def medium
    media.first
  end

  def medium_icon_url
    medium.try(:medium_icon_url) or page.icon
  end
  alias_method :icon, :medium_icon_url

  def small_icon_url
    medium.try(:small_icon_url) or page.top_image.try(:small_icon_url)
  end
end
