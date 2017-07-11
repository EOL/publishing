class Page < ActiveRecord::Base
  searchkick word_start: [:scientific_name, :preferred_vernacular_strings]

  belongs_to :native_node, class_name: "Node"
  belongs_to :moved_to_page, class_name: "Page"
  belongs_to :medium, inverse_of: :pages

  has_many :nodes, inverse_of: :page
  has_many :collected_pages, inverse_of: :page
  has_many :vernaculars, inverse_of: :page
  has_many :preferred_vernaculars, -> { preferred }, class_name: "Vernacular"
  has_many :scientific_names, inverse_of: :page
  has_many :synonyms, -> { synonym }, class_name: "ScientificName"
  has_many :preferred_scientific_names, -> { preferred },
    class_name: "ScientificName"
  has_many :resources, through: :nodes

  # NOTE: this is too complicated, I think: it's not working as expected when
  # preloading. (Perhaps due to the scope.)
  has_many :page_icons, inverse_of: :page
  # Only the last one "sticks":
  has_one :page_icon, -> { most_recent }

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

  # NOTE: you cannot preload the node ancestors; it needs to call the method
  # from the module. NOTE: not loading media, because for large pages, that's a
  # long query, and we only want one page. Besides, it's loaded in a separate
  # instance variable...
  scope :preloaded, -> do
    includes(:preferred_vernaculars, :medium, :occurrence_map,
      referents: :references, native_node: :rank,
      articles: [:license, :sections, :bibliographic_citation,
        :location, :resource, attributions: :role])
  end

  # NOTE: I've not tested this; might not be the most efficient set: ...I did
  # notice that vernaculars doesn't quite work; the scopes that are attached to
  # the (preferred and nonpreferred) interfere.
  scope :search_import, -> { includes(:scientific_names, :vernaculars, :native_node, resources: :partner) }

  def self.autocomplete(query, options = {})
    search(query, options.reverse_merge({
      fields: ["scientific_name^200", "preferred_vernacular_strings"],
      match: :word_start,
      limit: 10,
      load: false,
      misspellings: false,
      boost_by: { page_richness: { factor: 0.01 } }
    }))
  end

  # NOTE: we DON'T store :name becuse it will necessarily already be in one of
  # the other fields.
  def search_data
    {
      id: id,
      page_richness: page_richness,
      scientific_name: scientific_name,
      preferred_scientific_names: preferred_scientific_names,
      synonyms: synonyms,
      preferred_vernacular_strings: preferred_vernacular_strings,
      vernacular_strings: vernacular_strings,
      providers: providers,
      ancestry_ids: ancestry_ids,
      resource_pks: resource_pks,
      icon: icon,
      name: name,
      native_node: native_node
    }
  end

  def synonyms
    scientific_names.synonym.map { |n| n.canonical_form }
  end

  def resource_pks
    nodes.map(&:resource_pk)
  end

  def preferred_vernacular_strings
    vernaculars.preferred.map { |v| v.string }
  end

  def vernacular_strings
    vernaculars.nonpreferred.map { |v| v.string }
  end

  def providers
    resources.flat_map do |r|
      [r.name, r.partner.full_name, r.partner.short_name]
    end.uniq
  end

  def ancestry_ids
    Array(native_node.try(:ancestors).try(:pluck, :page_id)) + [id]
  end

  def descendant_species
    return species_count unless species_count.nil?
    count_species
  end

  def count_species
    return nil unless native_node
    count = native_node.leaves.
      where(["rank_id IN (?)", Rank.all_species_ids]).count
    update_attribute(:species_count, count)
    count
  end

  # MEDIA METHODS

  def sorted_articles
    return @articles if @articles
    @articles = if page_contents.loaded?
      page_contents.select { |pc| pc.content_type == "Article" }.map(&:content)
    else
      articles
    end
    @articles =
      @articles.sort_by do |a|
        a.first_section.try(:position) || 1000
      end
    @duplicate_articles = {}
    @articles.select { |a| a.sections.size > 1 }.each do |article|
      # NOTE: don't try to use a #delete here, it calls the Rails #delete!
      article.sections.each do |section|
        next if section == article.first_section
        @duplicate_articles[section] ||= []
        @duplicate_articles[section] << article
      end
    end
    @articles
  end

  def duplicate_articles
    sorted_articles unless @duplicate_articles
    @duplicate_articles
  end

  def article
    sorted_articles.first
  end

  def toc
    return @toc if @toc
    secs = sorted_articles.flat_map(&:sections).uniq
    @toc = if secs.empty?
      []
    else
      # Each section may have one (and ONLY one) parent, so we need to load
      # those, too...
      parent_ids = secs.map(&:parent_id).uniq
      parent_ids.delete(0)
      sec_ids = secs.map(&:id)
      parent_ids.delete_if { |pid| sec_ids.include?(pid) }
      parents = Section.where(id: parent_ids)
      secs.sort_by { |s| s.position }
      toc = []
      last_section = nil
      last_parent = nil
      # NOTE: UUUUUUGHHHHH! This is SOOO UGLY!  ...Can we do this a better way?
      sorted_articles.each do |a|
        this_section = a.first_section
        if this_section.nil? || this_section == last_section
          # DO nothing.
        else
          last_section = this_section
          if this_section.parent
            if last_parent == this_section.parent
              toc.last[this_section.parent] << this_section
            else
              last_parent = this_section.parent
              toc << {this_section.parent => [this_section]}
            end
          else
            last_parent = nil
            toc << this_section
          end
        end
      end
      toc
    end
  end

  # Without touching the DB, if you have the media preloaded:
  def _media_count
    page_contents.select { |pc| pc.content_type == "Medium" }.size
  end

  def icon
    medium && medium.medium_icon_url
  end

  def occurrence_map?
    occurrence_map
  end

  def map?
    occurrence_map? || ! maps.blank?
  end

  def maps
    media.where(subclass: Medium.subclasses[:map])
  end

  def map_count
    maps.count + (occurrence_map? ? 1 : 0)
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
    native_node.try(:rank) || I18n.t("ranks.not_given")
  end

  # TRAITS METHODS

  # NOTE: This page size is "huge" because we don't want pagination for data.
  # ...Mainly because it gets complicated quickly. Data rows can be in multiple
  # TOC items, and we want to be able to show all of the data in a single TOC
  # item. ...which I suppose we could manage by passing in a section id.
  # ...Hmmmn. We could. But we haven't been asked to, I'm going to hold off for
  # now. (NOTE: If we do that, we're going to need another method to pull in the
  # full TOC.)
  def data(page = 1, per = 2000)
    return @data[0..per] if @data
    data = TraitBank.by_page(id, page, per)
    # Self-healing count of number of data:
    if data.size != data_count
      update_attribute(:data_count, data.size)
    end
    @data_toc_needs_other = false
    @data_toc = data.flat_map do |t|
      next if t[:predicate][:section_ids].nil? # Usu. test data...
      secs = t[:predicate][:section_ids].split(",")
      @data_toc_needs_other = true if secs.empty?
      secs.map(&:to_i)
    end.uniq
    @data_toc = Section.where(id: @data_toc) unless @data_toc.empty?
    @data_loaded = true
    @data = data
  end

  def iucn_status_key
    # NOTE this is NOT self-healing. If you store the wrong value or change it,
    # it is up to you to fix the value on the Page instance. This is something
    # to be aware of!
    if iucn_status.nil? && @data_loaded
      status = if grouped_data.has_key?(Eol::Uris::Iucn.status)
        recs = grouped_data[Eol::Uris::Iucn.status]
        record = recs.find { |t| t[:resource_id] == Resource.iucn.id }
        record ||= recs.first
        TraitBank::Record.iucn_status_key(record)
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
    if geographic_context.nil? && @data_loaded
      keys = grouped_data.keys & Eol::Uris.geographics
      habitat = if keys.empty?
        ""
      else
        habitats = []
        keys.each do |uri|
          recs = grouped_data[uri]
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

  def should_show_icon?
    return nil unless native_node
    @should_show_icon ||= Rank.species_or_below.include?(native_node.rank_id)
  end

  def is_it_marine?
    if ! has_checked_marine? && @data_loaded
      recs = grouped_data[Eol::Uris.environment]
      if recs && recs.any? { |r| r[:object_term] &&
         r[:object_term][:uri] == Eol::Uris.marine }
        update_attribute(:is_marine, true)
        update_attribute(:has_checked_marine, true)
        return true
      else
        update_attribute(:is_marine, false)
        return false
      end
    else
      is_marine?
    end
  end

  def displayed_extinction_data
    recs = grouped_data[Eol::Uris.extinction]
    return nil if recs.nil? || recs.empty?
    # TODO: perhaps a better algorithm to pick which data to use if there's
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
    if ! has_checked_extinct? && @data_loaded
      # NOTE: this relies on #displayed_extinction_data ONLY returning an
      # "exinct" record. ...which, as of this writing, it is designed to do.
      update_attribute(:has_checked_extinct, true)
      if displayed_extinction_data
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
    @glossary ||= Rails.cache.fetch("/pages/#{id}/glossary", expires_in: 1.day) do
      TraitBank::Terms.page_glossary(id)
    end
  end

  def clear
    clear_caches
    recount
    data # Just to load them
    iucn_status = nil
    iucn_status_key
    geographic_context = nil
    habitats
    has_checked_marine = nil
    is_it_marine?
    has_checked_extinct = nil
    is_it_extinct?
    score_richness
    instance_variables.each do |v|
      # Skip Rails variables:
      next if [
        :@attributes, :@aggregation_cache, :@association_cache, :@readonly,
        :@destroyed, :@marked_for_destruction, :@destroyed_by_association,
        :@new_record, :@txn, :@_start_transaction_state, :@transaction_state,
        :@reflects_state, :@original_raw_attributes
      ].include?(v)
      remove_instance_variable(v)
    end
    reindex
    # TODO: we should also re-index all of the page_contents by checking direct
    # relationships to this page and its children. (I think this is better than
    # descendants; if you want to do an entire tree, that should be another
    # process; this reindex should just check that it's honoring the
    # relationships it has direct influence on.) We may also want to check node
    # relationships, but I'm not sure that's necessary. It's also possible there
    # will be other denormalized relationships to re-build here.
  end

  # NOTE: if you add caches IN THIS CLASS, then add them here:
  def clear_caches
    [
      "/pages/#{id}/glossary"
    ].each do |cache|
      Rails.cache.delete(cache)
    end
  end

  def recount
    [ "page_contents", "media", "articles", "links", "maps",
      "data", "nodes", "vernaculars", "scientific_names", "referents"
    ].each do |field|
      update_column("#{field}_count".to_sym, send(field).count)
    end
    count_species
  end

  def data_toc
    return @data_toc if @data_toc
    data
    @data_toc
  end

  def data_toc_needs_other?
    return @data_toc_needs_other if @data_toc_needs_other
    data
    @data_toc_needs_other
  end

  def grouped_data
    @grouped_data ||= data.group_by { |t| t[:predicate][:uri] }
  end

  def predicates
    @predicates ||= grouped_data.keys.sort do |a,b|
      glossary_names[a] <=> glossary_names[b]
    end
  end

  def object_terms
    @object_terms ||= glossary.keys - predicates
  end

  # REFERENCES METHODS

  def literature_and_references_count
    if referents.count != referents_count
      update_attribute(:referents_count, referents.count)
    end
    @literature_and_references_count ||= referents_count
  end

  def richness
    score_richness if self.page_richness.nil?
    page_richness
  end

  def score_richness
    update_attribute(:page_richness, RichnessScore.calculate(self))
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
