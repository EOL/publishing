class CollectedPage < ActiveRecord::Base
  belongs_to :page, inverse_of: :collected_pages
  belongs_to :collection, inverse_of: :collected_pages
  belongs_to :vernacular
  belongs_to :scientific_name
  belongs_to :medium

  has_many :collected_pages_media, -> { order(position: :asc) },
    inverse_of: :collected_page
  has_many :media, through: :collected_pages_media
  has_and_belongs_to_many :articles, -> { order(position: :asc) }
  has_and_belongs_to_many :links, -> { order(position: :asc) }

  acts_as_list scope: :collection

  # For convenience, this is duck-typed from CollectionAssociation (q.v.)
  def item
    page
  end

  def name
    vernacular.try(:string) or page.name
  end

  def scientific_name_string
    scientific_name.try(:canonical_form) or page.scientific_name
  end

  def medium_icon_url
    medium.try(:medium_icon_url) or page.icon
  end
  alias_method :icon, :medium_icon_url

  def small_icon_url
    medium.try(:small_icon_url) or page.top_image.try(:small_icon_url)
  end
end
