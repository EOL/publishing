class Publishing::PubMedia
  include Publishing::GetsLanguages
  include Publishing::GetsLicenses

  def self.import(resource, log, repo)
    Publishing::PubMedia.new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
    @media_by_page = {}
    @media_pks = []
    @media_id_by_pk = {}
    @contents = []
    @ancestry = {}
    @naked_pages = {}
  end

  # TODO: set these:
  # t.datetime :last_published_at
  # t.integer :last_publish_seconds
  def import
    @log.log('import_media')
    count = @repo.get_new(Medium) do |medium|
      debugger if medium[:subclass] != 'image' # TODO
      debugger if medium[:format] != 'jpg' # TODO
      # TODO Add usage_statement to database. Argh.
      medium.delete(:usage_statement)
      # NOTE: sizes are really "informational," for other people using that API. We don't need them:
      medium.delete(:sizes)
      # TODO: locations import
      # TODO: bibliographic_citations import
      lang = medium.delete(:language)
      # TODO: default language per resource?
      medium[:language_id] = lang ? get_language(lang) : get_language(code: "eng", group_code: "en")
      license_url = medium.delete(:license)
      medium[:license_id] = get_license(license_url)
      medium[:base_url] = "#{Rails.configuration.repository_url}/#{medium[:base_url]}" unless
        medium[:base_url] =~ /^http/
      @media_by_page[medium[:page_id]] = medium[:resource_pk]
      if medium[:page_id].blank?
        @log.log("Medium {#{medium[:resource_pk]}} skipped: missing page_id——perhaps node is missing?")
        next
      end
      @media_pks << medium[:resource_pk]
    end
    return if count.zero?
    @log.log('learn IDs...')
    @media_pks.in_groups_of(1000, false) do |group|
      media = Medium.where(resource_pk: group).select('id, resource_pk')
      media.each { |med| @media_id_by_pk[med.resource_pk] = med.id }
    end
    @log.log('learn Ancestry...')
    @media_by_page.keys.in_groups_of(1000, false) do |group|
      pages = Page.includes(native_node: { node_ancestors: :ancestor }).where(id: group)
      pages.each do |page|
        @ancestry[page.id] = page.ancestry_ids
        if page.medium_id.nil?
          @naked_pages[page.id] = page
          # If this guy doesn't have an icon, we need to walk up the tree to find more! :S
          Page.where(id: page.ancestry_ids).reverse.each do |ancestor|
            next if ancestor.id == page.id
            break if ancestor.medium_id
            @naked_pages[ancestor.id] = ancestor
          end
        end
      end
    end

    # I ran this manually to clean up when things didn't work. It suggests we should abstract this and remove.
    # Medium.where(resource: @resource.id).find_each do |medium|
    #   page_id = medium.page_id
    #   medium_pk = medium.resource_pk
    #   @contents << { page_id: page_id, source_page_id: page_id, position: 10000, content_type: 'Medium',
    #                  content_id: medium.id, resource_id: @resource.id }
    #   if @naked_pages.key?(page_id)
    #     @naked_pages[page_id].assign_attributes(medium_id: medium.id)
    #   end
    #   if @ancestry.key?(page_id)
    #     @ancestry[page_id].each do |ancestor_id|
    #       next if ancestor_id == page_id
    #       @contents << { page_id: ancestor_id, source_page_id: page_id, position: 10000, content_type: 'Medium',
    #         content_id: medium.id, resource_id: @resource.id }
    #       if @naked_pages.key?(ancestor_id)
    #         @naked_pages[ancestor_id].assign_attributes(medium_id: medium.id)
    #       end
    #     end
    #   end
    # end

    @log.log('build page contents...')
    @media_by_page.each do |page_id, medium_pk|
      # TODO: position. :(
      # TODO: trust...
      @contents << { page_id: page_id, source_page_id: page_id, position: 10000, content_type: 'Medium',
                     content_id: @media_id_by_pk[medium_pk], resource_id: @resource.id }
      if @naked_pages.key?(page_id)
        @naked_pages[page_id].assign_attributes(medium_id: @media_id_by_pk[medium_pk])
      end
      if @ancestry.key?(page_id)
        @ancestry[page_id].each do |ancestor_id|
          next if ancestor_id == page_id
          @contents << { page_id: ancestor_id, source_page_id: page_id, position: 10000, content_type: 'Medium',
            content_id: @media_id_by_pk[medium_pk], resource_id: @resource.id }
          if @naked_pages.key?(ancestor_id)
            @naked_pages[ancestor_id].assign_attributes(medium_id: @media_id_by_pk[medium_pk])
          end
        end
      end
    end
    @contents.in_groups_of(10_000, false) do |group|
      @log.log("import #{group.size} page contents...")
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      PageContent.import(group, on_duplicate_key_ignore: true)
    end
    unless @naked_pages.empty?
      @naked_pages.values.in_groups_of(10_000, false) do |group|
        @log.log("updating #{group.size} pages with icons...")
        Page.import!(group, on_duplicate_key_update: [:medium_id])
      end
    end
    @media_id_by_pk.values.in_groups_of(1000, false) do |group|
      PageContent.where(content_id: group).counter_culture_fix_counts
    end
  end
end
