class CollectedPage < ActiveRecord::Base
  belongs_to :page, inverse_of: :collected_pages
  belongs_to :collection, inverse_of: :collected_pages

  has_many :collected_pages_media, -> { order(position: :asc) },
    inverse_of: :collected_page
  has_many :media, through: :collected_pages_media
  has_and_belongs_to_many :articles, -> { order(position: :asc) }
  has_and_belongs_to_many :links, -> { order(position: :asc) }

  acts_as_list scope: :collection

  accepts_nested_attributes_for :collected_pages_media, allow_destroy: true

  counter_culture :collection

  # NOTE: not indexed if the page is missing!
  # searchable if: :page do
  #   integer :collection_id, stored: true
  #   text(:name) { page.name }
  #   text(:scientific_name) { page.scientific_name.gsub(/<\/?i>/, "") }
  #   text(:preferred_scientific_names) { page.preferred_scientific_names.
  #     map { |n| n.canonical_form.gsub(/<\/?i>/, "") } }
  #   text(:synonyms) {page.scientific_names.synonym.map { |n| n.canonical_form.gsub(/<\/?i>/, "") } }
  #   text(:vernaculars) { page.vernaculars.preferred.map { |v| v.string } }
  # end

  def self.find_pages(q, collection_id)
    CollectedPage.search do
      q = "*#{q}" unless q[0] == "*"
      fulltext q do
        fields(:name, :scientific_name, :preferred_scientific_names, :synonyms, :vernaculars)
      end
      with(:collection_id, collection_id)
    end
  end

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
    medium.try(:small_icon_url) or page.medium.try(:small_icon_url)
  end
end
