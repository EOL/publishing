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

  has_one :occurrence_map, inverse_of: :page

  has_and_belongs_to_many :referents

  # NOTE: You CANNOT preload both the top article AND the media. This seems to
  # be a Rails bug, but it is what it is. NOTE: you cannot preload the node
  # ancestors; it needs to call the method from the module. NOTE: not loading
  # media, because for large pages, that's a long query, and we only want one
  # page. Besides, it's loaded in a separate instance variable...
  scope :preloaded, -> do
    includes(:preferred_vernaculars, :native_node, :medium, :occurrence_map,
      referents: :references, articles: [:license, :sections, :bibliographic_citation,
        :location, :resource, attributions: :role])
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

  # Without touching the DB, if you have the media preloaded:
  def _media_count
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

  def occurrence_map?
    occurrence_map
  end

  def map?
    occurrence_map? || ! maps.blank?
  end

  def maps
    # TODO
    []
  end

  def sections
    @sections = articles.flat_map { |a| a.sections }.uniq
  end

  # NAMES METHODS

  # TODO: this is duplicated with node; fix.
  def name(language = nil)
    language ||= Language.current
    vernacular(language).try(:string) || scientific_name
  end

  def names_count
    # NOTE: there are no "synonyms!" Those are a flavor of scientific name.
    @names_count ||= vernaculars_count + scientific_names_count
  end

  # TODO: this is duplicated with node; fix. Can't (easily) use clever
  # associations here because of language. TODO: Aaaaaactually, we really need
  # to use GROUPS, not language IDs. (Or, at least, both, to make it efficient.)
  # Switch to that. Yeeesh.
  def vernacular(language = nil)
    if preferred_vernaculars.loaded?
      language ||= Language.english
      preferred_vernaculars.find { |v| v.language_id == language.id }
    else
      if vernaculars.loaded?
        language ||= Language.english
        vernaculars.find { |v| v.language_id == language.id and v.is_preferred? }
      else
        language ||= Language.english
        preferred_vernaculars.find { |v| v.language_id == language.id }
      end
    end
  end

  def scientific_name
    native_node.try(:canonical_form) || "NO NAME!"
  end

  def rank
    native_node.rank
  end

  # TRAITS METHODS

  # TODO: ideally we want to be able to paginate these! ...but that's really
  # hard, and ATM the query is pretty fast even for >100 traits, so we're not
  # doing that yet.
  def traits
    return @traits if @traits
    traits = TraitBank.by_page(id)
    # Self-healing count of number of traits:
    if traits.size != traits_count
      update_attribute(:traits_count, traits.size)
    end
    # TODO: do we need a glossary anymore, really?
    @glossary = TraitBank.glossary(traits)
    @traits_loaded = true
    # TODO: do we need the sort here?
    @traits = TraitBank.sort(traits)
  end

  def iucn_status_key
    # NOTE this is NOT self-healing. If you store the wrong value or change it,
    # it is up to you to fix the value on the Page instance. This is something
    # to be aware of! TODO: this should be one of the things we can "fix" with a
    # page reindex.
    if iucn_status.nil? && @traits_loaded
      status = if grouped_traits.has_key?(Eol::Uris::Iucn.status)
        recs = grouped_traits[Eol::Uris::Iucn.status]
        record = recs.find { |t| t[:resource_id] == Resource.iucn.id }
        record ||= recs.first
        TraitBank.iucn_status_key(record)
      else
        "unknown"
      end
      if iucn_status != status
        update_attribute(:iucn_status, status)
      end
      status
    else
      iucn_status
    end
  end

  def redlist_status
    # TODO
  end

  def habitats
    if geographic_context.nil? && @traits_loaded
      keys = grouped_traits.keys & Eol::Uris.geographics
      habitat = if keys.empty?
        ""
      else
        habitats = []
        keys.each do |uri|
          recs = grouped_traits[uri]
          habitats += recs.map do |rec|
            rec[:object_term] ? rec[:object_term][:name] : rec[:literal]
          end
        end
        habitats.join(", ")
      end
      if geographic_context != habitat
        update_attribute(:geographic_context, habitat)
      end
      habitat
    else
      geographic_context
    end
  end

  def is_it_marine?
    if ! has_checked_marine? && @traits_loaded
      recs = grouped_traits[Eol::Uris.environment]
      if recs && recs.any? { |r| r[:object_term] &&
         r[:object_term][:uri] == Eol::Uris.marine }
        update_attribute(:is_marine, true)
        return true
      else
        update_attribute(:is_marine, false)
        return false
      end
    else
      is_marine?
    end
  end

  def displayed_extinction_trait
    recs = grouped_traits[Eol::Uris.extinction]
    return nil if recs.empty?
    # TODO: perhaps a better algorithm to pick which trait to use if there's
    # more than one from a resource (probably the most recent):
    paleo = recs.find { |r| r[:resource_id] == Resource.paleo_db.id }
    ex_stat = recs.find { |r| r[:resource_id] == Resource.extinction_status.id }
    if paleo && ex_stat
      if ex_stat[:object_term] && ex_stat[:object_term][:uri] == Eol::Uris.extinct
        if paleo[:object_term] && paleo[:object_term][:uri] == Eol::Uris.extinct
          paleo
        else
          ex_stat
        end
      else
        nil
      end
    elsif paleo || ex_stat
      rec = [paleo, ex_stat].compact.first
      rec[:object_term] && rec[:object_term][:uri] == Eol::Uris.extinct ? rec :
        nil
    else
      recs.find { |rec| rec[:object_term] && rec[:object_term][:uri] == Eol::Uris.extinct }
    end
  end

  def is_it_extinct?
    if ! has_checked_extinct? && @traits_loaded
      # NOTE: this relies on #displayed_extinction_trait ONLY returning an
      # "exinct" record. ...which, as of this writing, it is designed to do.
      if displayed_extinction_trait
        update_attribute(:is_extinct, true)
        return true
      else
        update_attribute(:is_extinct, false)
        return false
      end
    else
      is_extinct?
    end
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

  # REFERENCES METHODS

  def literature_and_references_count
    if referents.count != referents_count
      update_attribute(:referents_count, referents.count)
    end
    @literature_and_references_count ||= referents_count
  end

  def richness_score
    RichnessScore.calculate(self)
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
