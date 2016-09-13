class Page < ActiveRecord::Base
  belongs_to :native_node, class_name: "Node"
  belongs_to :moved_to_page, class_name: "Page"

  has_many :nodes, inverse_of: :page
  has_many :collection_items, as: :item
  has_many :vernaculars, inverse_of: :page
  has_many :preferred_vernaculars, -> { preferred }, class_name: "Vernacular"
  has_many :scientific_names, inverse_of: :page
  has_many :synonyms, -> { synonym }, class_name: "ScientificName"
  has_many :preferred_scientific_names, -> { preferred },
    class_name: "ScientificName"
  has_many :resources, through: :nodes

  has_many :page_contents, -> { visible.not_untrusted }
  has_many :maps, through: :page_contents, source: :content, source_type: "Map"
  has_many :articles, through: :page_contents,
    source: :content, source_type: "Article"
  has_many :media, through: :page_contents,
    source: :content, source_type: "Medium"
  has_many :links, through: :page_contents,
    source: :content, source_type: "Link"
  has_many :images, -> { where(subclass: Medium.subclasses[:image]) },
    through: :page_contents, source: :content, source_type: "Medium"
  has_many :videos, -> { where(subclass: Medium.subclasses[:videos]) },
    through: :page_contents, source: :content, source_type: "Medium"
  has_many :sounds, -> { where(subclass: Medium.subclasses[:sounds]) },
    through: :page_contents, source: :content, source_type: "Medium"

  has_many :all_page_contents, -> { order(:position) }
  has_many :all_maps, through: :all_page_contents, source: :content, source_type: "Map"
  has_many :all_articles, through: :all_page_contents,
    source: :content, source_type: "Article"
  has_many :all_media, through: :all_page_contents,
    source: :content, source_type: "Medium"
  has_many :all_links, through: :all_page_contents,
    source: :content, source_type: "Link"
  has_many :all_images, -> { where(subclass: Medium.subclasses[:image]) },
    through: :all_page_contents, source: :content, source_type: "Medium"
  has_many :all_videos, -> { where(subclass: Medium.subclasses[:videos]) },
    through: :all_page_contents, source: :content, source_type: "Medium"
  has_many :all_sounds, -> { where(subclass: Medium.subclasses[:sounds]) },
    through: :all_page_contents, source: :content, source_type: "Medium"

  # Will return an array, even when there's only one, thus the plural names.
  # TODO: I don't like this. It means "figuring out" which are the top things
  # every single time the page is loaded, where we should probably have that
  # information denormalized and clear it whenever new candidates are added.
  has_many :top_maps, -> { limit(1) }, through: :page_contents, source: :content,
    source_type: "Map"
  has_many :top_articles, -> { limit(1) }, through: :page_contents,
    source: :content, source_type: "Article"
  has_many :top_links, -> { limit(6) }, through: :page_contents,
    source: :content, source_type: "Link"
  has_many :top_images,
    -> { where(subclass: Medium.subclasses[:image]).limit(6) },
    through: :page_contents, source: :content, source_type: "Medium"
  has_many :top_videos,
    -> { where(subclass: Medium.subclasses[:videos]).limit(1) },
    through: :page_contents, source: :content, source_type: "Medium"
  has_many :top_sounds,
    -> { where(subclass: Medium.subclasses[:sounds]).limit(1) },
    through: :page_contents, source: :content, source_type: "Medium"

  scope :preloaded, -> do
    includes(:preferred_vernaculars, :page_contents, :native_node)
  end

  scope :all_preloaded, -> do
    includes(:native_node, :vernaculars, :images, :videos, :sounds, :articles,
      :maps, :links)
  end

  # NOTE: Solr will be greatly expanded, later. For now, we ONLY need names:
  searchable do
    text :name, :boost => 4.0
    text :scientific_name, :boost => 10.0 do
      scientific_name.gsub(/<\/?i>/, "")
    end
    # TODO: We would like to add attributions, later.
    text :preferred_scientific_names, :boost => 8.0 do
      preferred_scientific_names.map { |sn| sn.canonical_form.gsub(/<\/?i>/, "") }
    end
    text :synonyms, :boost => 2.0 do
      scientific_names.synonym.map { |sn| sn.canonical_form.gsub(/<\/?i>/, "") }
    end
    text :preferred_vernaculars, :boost => 2.0 do
      vernaculars.preferred.map { |v| v.string }
    end
    text :vernaculars do
      vernaculars.nonpreferred.map { |v| v.string }
    end
    text :providers do
      resources.flat_map { |r| [r.name, r.partner.full_name, r.partner.short_name] }
    end
  end

  def glossary
    return @glossary if @glossary
    traits
    @glossary
  end

  # Without touching the DB:
  # NOTE: not used or spec'ed yet.
  def media_count
    page.page_contents.select { |pc| pc.content_type == "Medium" }.size
  end

  def name(language = nil)
    language ||= Language.english
    vernacular(language).try(:string) || scientific_name
  end

  def collect_with_icon
    top_image && top_image.medium_icon_url
  end

  # Can't (easily) use clever associations here because of language.
  def vernacular(language = nil)
    language ||= Language.english
    preferred_vernaculars.find { |v| v.language_id == language.id }
  end

  def scientific_name
    native_node.try(:canonical_form) || "NO NAME!"
  end

  def top_image
    @top_image ||= top_images.first
  end

  # TODO: ideally we want to be able to limit these! ...but that's really hard,
  # and ATM the query is pretty fast even for >100 traits, so we're not doing
  # that yet.
  def traits
    return @traits if @traits
    traits = TraitBank.by_page(id)
    @glossary = TraitBank.glossary(traits)
    @traits = traits.sort do |a,b|
      a_uri = @glossary[a[:predicate]]
      b_uri = @glossary[b[:predicate]]
      if a_uri && b_uri
        a_uri.name.downcase <=> b_uri.name.downcase
      elsif a_uri
        1
      elsif b_uri
        -1
      else
        0
      end
    end
  end
end
