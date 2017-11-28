module Import
  # Import::Repository
  class Repository
    attr_accessor :resource, :resources, :log, :pages, :run, :last_run_at, :since, :nodes, :ancestors, :identifiers,
      :names, :verns, :node_id_by_page, :traits, :traitbank_pages, :traitbank_suppliers, :traitbank_terms, :tax_stats,
      :languages, :licenses

    def self.sync
      # TODO.
    end

    def self.start
      instance = self.new
      instance.start
    end

    def initialize
      @resource = nil
      @log = nil
      @resources = []
      @pages = {}
      reset_resource # Not strictly required, but helps for debugging.
    end

    def start
      require 'csv'
      log("Starting import run...")
      get_import_run
      get_resources
      import_terms
      return nil if @resources.empty?
      @resources.each do |resource|
        # TODO: this is, of course, silly. create Import::Resource
        @resource = resource
        @log = @resource.create_log
        begin
          import_resource
          @log.complete
        rescue => e
          @log.fail(e)
        end
      end
      @log = nil
      # TODO: these logs end up attatched to a resource. They shouldn't be. ...Not sure where to move them, though.
      richness = RichnessScore.new
      # Note: this is quite slow, but searches won't work without it. :S
      pages = Page.where(id: @pages.keys).includes(:occurrence_map)
      log('score_richness_for_pages')
      # Clear caches that could have been affected TODO: more caches ... and move. It doesn't belong here.
      pages.find_each do |page|
        richness.calculate(page)
        Rails.cache.delete("/pages/#{page.id}/glossary")
      end
      log('pages.reindex')
      pages.reindex
      Rails.cache.delete("pages/index/stats")
      log('All Harvests Complete, stopping.', cat: :ends)
      @run.update_attribute(:completed_at, Time.now)
    end

    # TODO: set these:
    # t.datetime :last_published_at
    # t.integer :last_publish_seconds

    def get_import_run
      last_run = ImportRun.completed.last
      # NOTE: We use the CREATED time! We want all new data as of the START of the import. In pracice, this is less than
      # perfect... ideally, we would want a start time for each resource... but this should be adequate for our
      # purposes.
      @last_run_at = (last_run&.created_at || 10.years.ago).to_i
      @run = ImportRun.create
    end

    def get_resources
      log("Getting updated resources...")
      # If there are only a handful of resources, we've just created the DB and the max created_at is useless.
      url = "#{Rails.configuration.repository_url}/resources.json?since=#{@last_run_at}&"
      loop_over_pages(url, "resources") do |resource_data|
        resource = underscore_hash_keys(resource_data)
        resource[:repository_id] = resource.delete(:id)
        partner = resource.delete(:partner)
        # NOTE: resources that have no associated partner are PURELY test data in the repository database:
        next unless partner
        partner[:repository_id] = partner.delete(:id)
        partner = find_and_update_or_create(Partner, partner)
        resource[:partner_id] = partner.id
        resource = find_and_update_or_create(Resource, resource)
        @resources << resource
      end
    end

    def underscore_hash_keys(hash)
      new_hash = {}
      hash.each do |k, v|
        val = v.is_a?(Hash) ? underscore_hash_keys(v) : v
        new_hash[k.underscore.to_sym] = val
      end
      new_hash
    end

    def find_and_update_or_create(klass, model)
      if klass.where(repository_id: model[:repository_id]).exists?
        m = klass.find_by_repository_id(model[:repository_id])
        m.update_attributes(model)
        m
      else
        klass.create(model)
      end
    end

    def reset_resource
      @node_pks = []
      @ancestors = []
      @identifiers = []
      @names = []
      @verns = []
      @node_id_by_page = {}
      @traits = []
      @traitbank_pages = {}
      @traitbank_suppliers = {}
      @traitbank_terms = {}
      @tax_stats = {}
      @languages = {}
      @licenses = {}
      @since = @resource&.import_logs&.successful&.any? ?
        @resource.import_logs.successful.last.created_at :
        10.years.ago
    end

    def import_resource
      log("Importing Resource: #{@resource.name} (#{@resource.id})")
      reset_resource
      import_nodes
      create_new_pages
      import_scientific_names
      import_vernaculars
      import_media
      import_traits
      @node_id_by_page.keys.each { |k| @pages[k] = true }
      log('Complete', cat: :ends)
    end

    def import_nodes
      log('import_nodes')

      count = get_new_instances_from_repo(Node) do |node|
        node_pk = node[:resource_pk]
        @node_pks << node_pk
        rank = node.delete(:rank)
        identifiers = node.delete(:identifiers)
        # Keeping these for posterity: I had altered the JSON output of the API and needed to parse out the sciname:
        # sname = node.delete(:scientific_name)
        # node[:scientific_name] = sname['normalized'] || sname['verbatim']
        # node[:canonical_form] = sname['canonical'] || sname['verbatim']
        @identifiers += identifiers.map { |ident| { identifier: ident, node_resource_pk: node_pk } }
        # TODO: move this to a hash-cache thingie... (mind the downcase)
        unless rank.nil?
          rank = Rank.where(name: rank).first_or_create do |r|
            r.name = rank.downcase
            r.treat_as = Rank.guess_treat_as(rank)
          end
          node[:rank_id] = rank.id
        end
        if (ancestors = node.delete(:ancestors))
          ancestors.each_with_index do |anc, depth|
            next if anc == node_pk
            @ancestors << { node_resource_pk: node_pk, ancestor_resource_pk: anc,
                            resource_id: @resource.id, depth: depth }
          end
        end
        # TODO: we should have the repository calculate the depth...
        # So, until we parse the WHOLE thing (at the source), we have to deal with this. Probably fair enough to include
        # it here anyway:
        node[:canonical_form] = "Unamed clade #{node[:resource_pk]}" if node[:canonical_form].blank?
        node[:scientific_name] = node[:canonical_form] if node[:scientific_name].blank?
        # We do store the landmark ID, but this is helpful.
        node[:has_breadcrumb] = node.key?(:landmark) && node[:landmark] != "no_landmark"
        node[:landmark] = Node.landmarks[node[:landmark]]
      end
      return if count.zero?
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      @identifiers.in_groups_of(10_000, false) do |group|
        Identifier.import(group, on_duplicate_key_ignore: true, validate: false)
      end
      @ancestors.in_groups_of(10_000, false) do |group|
        NodeAncestor.import(group, on_duplicate_key_ignore: true, validate: false)
      end
      Node.propagate_id(resource: @resource, fk: 'parent_resource_pk', other: 'nodes.resource_pk',
                        set: 'parent_id', with: 'id', resource_id: @resource.id)
      Identifier.propagate_id(resource: @resource, fk: 'node_resource_pk', other: 'nodes.resource_pk',
                              set: 'node_id', with: 'id', resource_id: @resource.id)
      NodeAncestor.propagate_id(resource: @resource, fk: 'ancestor_resource_pk', other: 'nodes.resource_pk',
                                set: 'ancestor_id', with: 'id', resource_id: @resource.id)
      NodeAncestor.propagate_id(resource: @resource, fk: 'node_resource_pk', other: 'nodes.resource_pk',
                                set: 'node_id', with: 'id', resource_id: @resource.id)
    end

    def create_new_pages
      log('create_new_pages')
      # CREATE NEW PAGES: TODO: we need to recognize DWH and allow it to have its pages assign the native_node_id to it,
      # regardless of other nodes. (Meaning: if a resource creates a weird page, the DWH later recognizes it and assigns
      # itself to that page, then the native_node_id should *change* to the DWH id.)
      have_pages = []
      @node_pks.in_groups_of(1000, false) do |group|
        page_ids = []
        Node.where(resource_pk: group).select("id, page_id").find_each do |node|
          @node_id_by_page[node.page_id] = node.id
          page_ids << node.page_id
        end
        have_pages += Page.where(id: page_ids).pluck(:id)
      end
      missing = @node_id_by_page.keys - have_pages
      pages = missing.map { |id| { id: id, native_node_id: @node_id_by_page[id], nodes_count: 1 } }
      if pages.empty?
        log('There were NO new pages, skipping...', cat: :warns)
        return
      end
      pages.in_groups_of(1000, false) do |group|
        log("importing #{group.size} Pages", cat: :infos)
        # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
        # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
        Page.import!(group, on_duplicate_key_ignore: true)
      end
      log('fixing counter_culture counts for Node...')
      Node.where(resource_id: @resource.id).counter_culture_fix_counts
    end

    def import_scientific_names
      log('import_scientific_names')
      bad_names = []
      count = get_new_instances_from_repo(ScientificName) do |name|
        status = name.delete(:taxonomic_status)
        status = "accepted" if status.blank?
        unless status.nil?
          name[:taxonomic_status_id] = get_tax_stat(status)
        end
        name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
        name[:italicized].gsub!(/, .*/, ", et al.") if name[:italicized] && name[:italicized].size > 200
        if name[:page_id].nil?
          bad_names << name[:canonical_form]
          name = nil
        end
      end
      if bad_names.size.positive?
        log("** WARNING: you've got #{bad_names.size} scientific_names with no page_id!")
        bad_names.in_groups_of(20, false) do |group|
          log("BAD: #{group.join('; ')}")
        end
      end
      return if count.zero?
      ScientificName.propagate_id(resource: @resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                         set: 'node_id', with: 'id', resource_id: @resource.id)
      # TODO: This doesn't ensure we're getting *preferred* scientific_name.
      Node.propagate_id(resource: @resource, fk: 'id',  other: 'scientific_names.node_id',
                         set: 'scientific_name', with: 'italicized', resource_id: @resource.id)
      log('fixing counter_culture counts for ScientificName...')
      ScientificName.counter_culture_fix_counts
    end

    def import_vernaculars
      log('import_vernaculars')

      count = get_new_instances_from_repo(Vernacular) do |name|
        name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
        name[:string] = name.delete(:verbatim)
        name.delete(:language_code_verbatim) # We don't use this.
        lang = name.delete(:language)
        # TODO: default language per resource?
        name[:language_id] = lang ? get_language(lang) : get_language(code: "eng", group_code: "en")
        name[:is_preferred_by_resource] = name.delete(:is_preferred)
      end
      return if count.zero?
      Vernacular.propagate_id(resource: @resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                         set: 'node_id', with: 'id', resource_id: @resource.id)
      log('fixing counter_culture counts for ScientificName...')
      Vernacular.counter_culture_fix_counts
      # TODO: update preferred = true where page.vernaculars_count = 1...
      Vernacular.joins(:page).where(['pages.vernaculars_count = 1 AND vernaculars.is_preferred_by_resource = ? '\
        'AND vernaculars.resource_id = ?', true, @resource.id]).update_all(is_preferred: true)
    end

    def import_media
      log('import_media')
      @media_by_page = {}
      @media_pks = []
      count = get_new_instances_from_repo(Medium) do |medium|
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
        debugger if medium[:page_id].blank? # This would otherwise cause the medium to be invisible. :S
        @media_pks << medium[:resource_pk]
      end
      return if count.zero?
      @media_id_by_pk = {}
      log('learn IDs...')
      @media_pks.in_groups_of(1000, false) do |group|
        media = Medium.where(resource_pk: group).select('id, resource_pk')
        media.each { |med| @media_id_by_pk[med.resource_pk] = med.id }
      end
      @contents = []
      @ancestry = {}
      @naked_pages = {}
      log('learn Ancestry...')
      @media_by_page.keys.in_groups_of(1000, false) do |group|
        pages = Page.includes(native_node: { node_ancestors: :ancestor }).where(id: group)
        pages.each do |page|
          @ancestry[page.id] = page.ancestry_ids
          if page.medium_id.nil?
            @naked_pages[page.id] = page
            # If this guy doesn't have an icon, we need to walk up the tree to find more! :S
            Page.where(id: page.ancestry_ids).reverse.each do |ancestor|
              next if ancestor.id == page.id
              last if ancestor.medium_id
              @naked_pages[ancestor.id] = ancestor
            end
          end
        end
      end

      log('build page contents...')
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
        log("import #{group.size} page contents...")
        # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
        # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
        PageContent.import(group, on_duplicate_key_ignore: true)
      end
      unless @naked_pages.empty?
        @naked_pages.values.in_groups_of(10_000, false) do |group|
          log("updating #{group.size} pages with icons...")
          Page.import!(group, on_duplicate_key_update: [:medium_id])
        end
      end
      @media_id_by_pk.values.in_groups_of(1000, false) do |group|
        PageContent.where(content_id: group).counter_culture_fix_counts
      end
    end

    def import_traits
      log('import_traits')
      TraitBank::Admin.remove_for_resource(@resource) # TEMP!!! DELETEME ... you don't want to do this forever, when we have deltas.
      trait_rows = []
      meta_rows = []
      trait_rows << %i[page_id scientific_name resource_pk predicate sex lifestage statistical_method source
        target_page_id target_scientific_name value_uri value_literal value_num units]
      meta_rows << %i[trait_resource_pk predicate value_literal value_num value_uri units sex lifestage
        statistical_method source]
      log('read_traits')
      url = "#{Rails.configuration.repository_url}/resources/#{@resource.repository_id}/traits.json?"
      loop_over_pages(url, "traits") do |trait_data|
        trait = underscore_hash_keys(trait_data)
        row = []
        trait_rows.first.each do |header|
          row << trait[header]
        end
        trait_rows << row
        meta = trait_data.delete(:metadata)
        meta_rows.first do |header|
          if header == :trait_resource_pk
            meta_rows << trait[:resource_pk]
          else
            meta_rows << meta[header]
          end
        end
        meta_rows << row
      end
      log('read_associations')
      url = "#{Rails.configuration.repository_url}/resources/#{@resource.repository_id}/assocs.json?"
      loop_over_pages(url, "assocs") do |assoc_data|
        assoc = underscore_hash_keys(assoc_data)
        row = []
        trait_rows.first.each do |header|
          row << assoc[header]
        end
        trait_rows << row
        meta = assoc_data.delete(:metadata)
        meta_rows.first do |header|
          if header == :trait_resource_pk
            meta_rows << assoc[:resource_pk]
          else
            meta_rows << meta[header]
          end
        end
        meta_rows << row
      end
      return if trait_rows.size <= 1
      log("slurping traits and associations (#{trait_rows.size - 1}) and all metadata (#{meta_rows.size - 1}, total #{trait_rows.size + meta_rows.size - 2})")
      traits_file = Rails.public_path.join("traits_#{@resource.id}.csv")
      meta_traits_file = Rails.public_path.join("meta_traits_#{@resource.id}.csv")
      CSV.open(traits_file, 'w') { |csv| trait_rows.each { |row| csv << row } }
      CSV.open(meta_traits_file, 'w') { |csv| meta_rows.each { |row| csv << row } }
      count = TraitBank.slurp_traits(@resource.id)
      log("Created #{count} associations (including metadata).")
      File.unlink(traits_file) if File.exist?(traits_file)
      File.unlink(meta_traits_file) if File.exist?(meta_traits_file)
    end

    def get_existing_terms
      terms = {}
      Rails.cache.delete("trait_bank/terms_count/include_hidden")
      count = TraitBank::Terms.count(include_hidden: true)
      per = 2000
      pages = (count / per.to_f).ceil
      (1..pages).each do |page|
        Rails.cache.delete("trait_bank/full_glossary/#{page}/include_hidden")
        TraitBank::Terms.full_glossary(page, per, include_hidden: true).compact.map { |t| t[:uri] }.each { |uri| terms[uri] = true }
      end
      terms
    end

    # TODO: move this to a CSV import. So much faster...
    def import_terms
      log("Importing terms...")
      terms = get_existing_terms
      knew = 0
      new_terms = 0
      skipped = 0
      url = "#{Rails.configuration.repository_url}/terms.json?per_page=1000&since=#{@last_run_at}&"
      loop_over_pages(url, "terms") do |term_data|
        term = underscore_hash_keys(term_data)
        knew += 1 if terms.key?(term[:uri])
        next if terms.key?(term[:uri])
        if Rails.env.development? && term[:uri] =~ /wikidata\.org\/entity/ # There are many, many of these. :S
          skipped += 1
          next
        end
        puts "++ New term: #{term[:uri]}" if terms.size > 1000 # Don't bother saying if we didn't have any at all!
        new_terms += 1
        # TODO: section_ids
        term[:type] = term[:used_for]
        TraitBank.create_term(term)
      end
      log("Finished importing terms: #{new_terms} new, #{knew} known, #{skipped} skipped.")
    end

    def get_new_instances_from_repo(klass)
      type = klass.class_name.underscore.pluralize.downcase
      total_count = 0
      things = []
      url = "#{Rails.configuration.repository_url}/resources/#{@resource.repository_id}/#{type}.json?"
      loop_over_pages(url, type.camelize(:lower)) do |thing_data|
        thing = underscore_hash_keys(thing_data)
        thing.merge!(resource_id: @resource.id)
        if thing
          begin
            yield(thing)
            things << thing
            total_count += 1
          rescue => e
            log("FAILED to add #{klass.class_name.downcase}: #{e.message}", cat: :errors)
            log("MISSING #{klass.class_name.downcase}: #{thing.inspect}", cat: :errors)
          end
        end
        if things.size >= 10_000
          log("importing #{things.size} #{klass.name.pluralize}")
          # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when
          # I want to ignore the ones we already had (I would delete things first if I wanted to replace them):
          klass.import(things, on_duplicate_key_ignore: true, validate: false)
          things = []
        end
      end
      if things.any?
        log("importing #{things.size} #{klass.name.pluralize}")
        klass.import(things, on_duplicate_key_ignore: true, validate: false)
      end
      if total_count.zero?
        log("There were NO new #{klass.name.pluralize.downcase}, skipping...", cat: :warns)
      else
        log("Total #{klass.name.pluralize} Published: #{total_count}")
      end
      total_count
    end

    def loop_over_pages(url_without_page, key)
      page = 1
      total_pages = 2 # Dones't matter YET... will be populated in a bit...
      while page <= total_pages
        url = "#{url_without_page}page=#{page}"
        html_response = Net::HTTP.get(URI.parse(url))
        begin
          response = JSON.parse(html_response)
        rescue => e
          log("!! Failed to read #{key} page #{page}! #{e.message[0..1000]}", cat: :errors)
        end
        total_pages = response["totalPages"]
        return unless response.key?(key) && total_pages.positive? # Nothing returned, otherwise.
        if page == 1 || (page % 25).zero?
          pct = (page / total_pages.to_f * 100).ceil rescue '??'
          log("Importing #{key.pluralize}: page #{page}/#{total_pages} (#{pct}%)", cat: :infos)
        end
        response[key].each do |data|
          yield(data)
        end
        page += 1
      end
    end

    def import_trait(trait)
      page_id = trait.delete(:page_id)
      if page_id.nil?
        log("Skipping trait with no page_id: #{trait.inspect}", cat: :warns)
        return nil
      end
      trait[:page] = find_or_add_page(page_id)
      res_id = @resource.id
      trait[:supplier] = @traitbank_suppliers[res_id] || add_supplier(res_id)
      pred = trait.delete(:predicate)
      unit = trait.delete(:units)
      val_uri = trait.delete(:value_uri)
      val_num = trait.delete(:value_num)
      trait[:measurement] = val_num if val_num
      trait[:predicate] = @traitbank_terms[pred] || add_term(pred)
      trait[:units] = @traitbank_terms[unit] || add_term(unit)
      trait[:object_term] = @traitbank_terms[val_uri] || add_term(val_uri)
      # TODO: we'll actually get a bunch of other meta-traits on the "children", but TraitBank can't show them yet, so
      # I'm not harvesting them. This is post-MVP stuff anyway. So I'm handling them identically for now:
      metadata = trait.delete(:metadata) || []
      children = trait.delete(:children)
      metadata += children if children
      trait[:metadata] = metadata.compact.map do |m_d|
        md = underscore_hash_keys(m_d)
        md_pred = md.delete(:predicate)
        md_val = md.delete(:value_uri)
        md_unit = md.delete(:units)
        md[:predicate] = @traitbank_terms[md_pred] || add_term(md_pred)
        md[:object_term] = @traitbank_terms[md_val] || add_term(md_val)
        md[:units] = @traitbank_terms[md_unit] || add_term(md_unit)
        md[:literal] = md.delete(:value_literal)
        # TODO: I would feel better if we did more to check the measurement;
        # if there are units, we should have a measurement!
        md[:measurement] = md.delete(:value_num)
        # TODO: add those back as links...
        md.symbolize_keys
      end
      trait[:statistical_method] = trait.delete(:statistical_method)
      trait[:literal] = trait.delete(:value_literal)
      trait[:source] = trait.delete(:source)
      # The rest of the keys are "just right" and will work as-is:
      begin
        TraitBank.create_trait(trait)
      rescue Excon::Error::Socket => e
        begin
          TraitBank.create_trait(trait)
        rescue
          log("WARNING: could not add trait with ID: #{trait[:resource_pk]} Page: "\
            "#{trait[:page][:data][:page_id]} Predicate: #{trait[:predicate][:data][:uri]}", cat: :warns)
        end
      end
    end

    def find_or_add_page(page_id)
      return @traitbank_pages[page_id] if @traitbank_pages.key?(page_id)
      tb_page = TraitBank.create_page(page_id)
      tb_page = tb_page.first if tb_page.is_a?(Array)
      if Page.exists?(page_id)
        page = Page.find(page_id)
        parent_id = page.try(:native_node).try(:parent).try(:page_id)
        if parent_id && !TraitBank.page_has_parent?(tb_page, parent_id)
          parent = @traitbank_pages[page_id] || find_or_add_page(parent_id)
          parent = parent.first if parent.is_a?(Array)
          result = TraitBank.add_parent_to_page(parent, tb_page)
          unless result[:added]
            log("Skipped adding #{parent_id} as a parent to #{page_id}: #{result[:message]}", cat: :warns)
          end
        end
      else
        log("Trait attempts to use missing page: #{page_id}, ignoring links", cat: :warns)
      end
      @traitbank_pages[page_id] = tb_page
      tb_page
    end

    def add_supplier(res_id)
      resource = TraitBank.create_resource(res_id)
      resource = resource.first if resource.is_a?(Array)
      @traitbank_suppliers[res_id] = resource
      resource
    end

    def add_term(uri)
      return(nil) if uri.blank?
      term =
        begin
          TraitBank.create_term(
            uri: uri,
            is_hidden_from_overview: true,
            is_hidden_from_glossary: true,
            name: uri,
            section_ids: [],
            definition: "auto-created, was empty",
            comment: "",
            attribution: ""
          )
        rescue Neography::PropertyValueException => e
          log("** WARNING: Failed to set property on term... #{e.message}")
          log('** This seems to occur with some bad trait data (passing in hashes instead of strings)')
        end
      @traitbank_terms[uri] = term
    end

    def get_tax_stat(status)
      return @tax_stats[status] if @tax_stats.key?(status)
      @tax_stats[status] = TaxonomicStatus.find_or_create_by(name: status).id
    end

    def get_language(hash)
      return @languages[hash[:group_code]] if @languages.key?(hash[:group_code])
      lang = Language.where(group: hash[:group_code]).first_or_create do |l|
        l.group = hash[:group_code]
        l.code = hash[:code]
      end
      @languages[hash[:group_code]] = lang.id
    end

    def get_license(url)
      if url.blank?
        return @resource.default_license&.id || License.public_domain.id
      end
      return @licenses[url] if @licenses.key?(url)
      if (license = License.find_by_source_url(url))
        return @licenses[url] = license.id
      end
      name =
        if url =~ /creativecommons.*\/licenses/
          "cc-" + url.split('/')[-2]
        else
          url.split('/').last.titleize
        end
      license = License.create(name: name, source_url: url, can_be_chosen_by_partners: false)
      @licenses[url] = license.id
    end

    def log(what, type = nil)
      if @log.nil?
        cat = type && type.key?(:cat) ? type[:cat] : :starts
        puts("[#{Time.now.strftime('%H:%M:%S')}] (#{cat}) #{what}")
        return nil
      end
      @log.log(what, type)
    end
  end
end
