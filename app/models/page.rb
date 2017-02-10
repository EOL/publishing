class Page < ActiveRecord::Base
  belongs_to :native_node, class_name: "Node"
  belongs_to :moved_to_page, class_name: "Page"

  has_many :nodes, inverse_of: :page
  has_many :collected_pages, inverse_of: :page
  has_many :vernaculars, inverse_of: :page
  has_many :preferred_vernaculars, -> { preferred }, class_name: "Vernacular"
  has_many :scientific_names, inverse_of: :page
  has_many :synonyms, -> { synonym }, class_name: "ScientificName"
  has_many :preferred_scientific_names, -> { preferred },
    class_name: "ScientificName"
  has_many :resources, through: :nodes

  has_many :page_icons, inverse_of: :page
  # Only the last one "sticks":
  has_one :page_icon, -> { most_recent }
  has_one :medium, through: :page_icon

  has_many :page_contents, -> { visible.not_untrusted.order(:position) }
  has_many :articles, through: :page_contents,
    source: :content, source_type: "Article"
  has_many :media, through: :page_contents,
    source: :content, source_type: "Medium"
  has_many :links, through: :page_contents,
    source: :content, source_type: "Link"

  has_many :all_page_contents, -> { order(:position) }, class_name: "PageContent"

  # NOTE: You CANNOT preload both the top article AND the media. This seems to
  # be a Rails bug, but it is what it is. NOTE: you cannot preload the node
  # ancestors; it needs to call the method from the module. NOTE: not loading
  # media, because for large pages, that's a long query, and we only want one
  # page. Besides, it's loaded in a separate instance variable...
  scope :preloaded, -> do
    includes(:preferred_vernaculars, :native_node, :medium,
      articles: [:license, :sections, :bibliographic_citation, :location,
        :resource, attributions: :role])
  end

  # NOTE: Solr will be greatly expanded, later. For now, we ONLY need names:
  searchable do
    text :name, :boost => 4.0
    text :scientific_name, :boost => 10.0 do
      scientific_name.gsub(/<\/?i>/, "")
    end
    # TODO: We would like to add attributions, later.
    text :preferred_scientific_names, :boost => 8.0 do
      preferred_scientific_names.map { |n| n.canonical_form.gsub(/<\/?i>/, "") }
    end
    text :synonyms, :boost => 2.0 do
      scientific_names.synonym.map { |n| n.canonical_form.gsub(/<\/?i>/, "") }
    end
    text :preferred_vernaculars, :boost => 2.0 do
      vernaculars.preferred.map { |v| v.string }
    end
    text :vernaculars do
      vernaculars.nonpreferred.map { |v| v.string }
    end
    text :providers do
      resources.flat_map do |r|
        [r.name, r.partner.full_name, r.partner.short_name]
      end
    end
  end

  # MEDIA METHODS

  def article
    if page_contents.loaded?
      page_contents.find { |pc| pc.content_type == "Article" }.try(:content)
    else
      articles.first
    end
  end

  # Without touching the DB:
  def media_count
    page_contents.select { |pc| pc.content_type == "Medium" }.size
  end

  def icon
    top_image && top_image.medium_icon_url
  end

  def top_image
    @top_image ||= begin
      if medium
        medium
      elsif page_contents.loaded?
        page_contents.find { |pc| pc.content_type == "Medium" }.try(:content)
      else
        media.first
      end
    end
  end

  # NAMES METHODS

  # TODO: this is duplicated with node; fix.
  def name(language = nil)
    language ||= Language.english
    vernacular(language).try(:string) || scientific_name
  end

  def names_count
    @names_count ||= vernaculars.size + scientific_names.size
  end

  # TODO: this is duplicated with node; fix.
  # Can't (easily) use clever associations here because of language.
  def vernacular(language = nil)
    if preferred_vernaculars.loaded?
      language ||= Language.english
      preferred_vernaculars.find { |v| v.language_id == language.id }
    else
      if vernaculars.loaded?
        language ||= Language.english
        vernaculars.find { |v| v.language_id == language.id and v.is_preferred? }
      else
        preferred_vernaculars.current_language.first
      end
    end
  end

  def scientific_name
    native_node.try(:canonical_form) || "NO NAME!"
  end

  # TRAITS METHODS

  # TODO: ideally we want to be able to limit these! ...but that's really hard,
  # and ATM the query is pretty fast even for >100 traits, so we're not doing
  # that yet.
  def traits
    return @traits if @traits
    traits = TraitBank.by_page(id)
    # TODO: do we need a glossary anymore, really?
    @glossary = TraitBank.glossary(traits)
    # TODO: do we need the sort here?
    @traits = TraitBank.sort(traits)
  end

  def glossary
    return @glossary if @glossary
    traits
    @glossary
  end

  def grouped_traits
    @grouped_traits ||= traits.group_by { |t| t[:predicate][:uri] }
  end

  def predicates
    @predicates ||= grouped_traits.keys.sort do |a,b|
      glossary_names[a] <=> glossary_names[b]
    end
  end

  private

  def first_image_content
    page_contents.find { |pc| pc.content_type == "Medium" && pc.content.is_image? }
  end

  # TODO: spec
  # NOTE: this is just used for sorting.
  def glossary_names
    @glossary_names ||= begin
      gn = {}
      glossary.each do |uri, hash|
        name = glossary[uri][:name] ? glossary[uri][:name].downcase :
          glossary[uri][:uri].downcase.gsub(/^.*\//, "").humanize.downcase
        gn[uri] = name
      end
      gn
    end
  end
end
