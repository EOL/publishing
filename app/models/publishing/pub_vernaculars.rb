class Publishing::PubVernaculars
  include Publishing::GetsLanguages

  def self.import(resource, log, repo)
    log ||= Publishing::PubLog.new(resource)
    a_long_long_time_ago = 1202911078 # 10 years ago when this was written; no sense coding it.
    repo ||= Publishing::Repository.new(resource: resource, log: log, since: a_long_long_time_ago)
    Publishing::PubVernaculars.new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
    @languages = {}
  end

  def import
    @log.log('import_vernaculars')
    pages = {}
    count = @repo.get_new(Vernacular) do |name|
      name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
      name[:string] = name.delete(:verbatim)
      name.delete(:language_code_verbatim) # We don't use this.
      lang = name.delete(:language)
      # TODO: default language per resource?
      name[:language_id] = lang ? get_language(lang) : get_language(code: "eng", group_code: "en")
      name[:is_preferred_by_resource] = name.delete(:is_preferred)
      pages[name[:page_id]] ||= true
    end
    return if count.zero?
    Vernacular.propagate_id(fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                            set: 'node_id', with: 'id', resource_id: @resource.id)
    # TMP: [faster for now]  @log.log('fixing counter_culture counts for ScientificName...')
    # Vernacular.counter_culture_fix_counts
    prefer_names_where_page_has_no_preferred_names(pages.keys)
  end

  def prefer_names_where_page_has_no_preferred_names(pages)
    pages.in_groups_of(10_000, false) do |page_set|
      pages_which_have_vernaculars_preferred_by_resource = Vernacular.where(page_id: page_set,
        is_preferred_by_resource: true).pluck(:page_id).uniq
      pages_which_already_have_preferred_name =
        Vernacular.where(page_id: pages_which_have_vernaculars_preferred_by_resource, is_preferred: true).
        pluck(:page_id).uniq
      pages_where_our_name_should_be_preferred = pages_which_have_vernaculars_preferred_by_resource -
        pages_which_already_have_preferred_name
      Vernacular.where(page_id: pages_where_our_name_should_be_preferred, resource_id: @resource.id,
        is_preferred_by_resource: true).update_all(is_preferred: true)
    end
  end
end
