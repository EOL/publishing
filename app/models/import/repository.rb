module Import
  class Repository
    attr_accessor :resource

    def self.sync
      # TODO.
    end

    # rake db:reset ; rails runner "Import::Repository.start(10.years.ago)"
    def self.start(since = nil)
      instance = self.new(since || 10.years.ago)
      instance.start
    end

    def initialize(since)
      @since = since
      @resource = nil
      @resources = []
      @pages = {}
      reset_resource # Not strictly required, but helps for debugging.
    end

    def start
      get_resources
      return nil if @resources.empty?
      @resources.each do |resource|
        # TODO: this is, of course, silly. create Import::Resource
        @resource = resource
        begin
          import_resource
        rescue => e
          log("!! ERROR: #{e.message}\n#{e.backtrace}")
        end
      end
      richness = RichnessScore.new
      # Note: this is quite slow, but searches won't work without it. :S
      pages = Page.where(id: @pages.keys).includes(:occurrence_map)
      log('## score_richness_for_pages')
      # Clear caches that could have been affected TODO: more
      pages.each do |page|
        richness.calculate(page)
        Rails.cache.delete("/pages/#{page.id}/glossary")
      end
      log('## pages.reindex')
      pages.reindex
    end

    # TODO: set these:
    # t.datetime :last_published_at
    # t.integer :last_publish_seconds

    def get_resources
      url = "#{Rails.configuration.repository_url}/resources.json?since=#{@since.to_i}&"
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
      @nodes = []
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
    end

    def import_resource
      log('{{ START IMPORT')
      log("?? Resource: #{@resource.name} (#{@resource.id})")
      reset_resource
      import_nodes
      create_new_pages
      import_scientific_names
      import_vernaculars
      import_media
      import_traits
      @node_id_by_page.keys.each { |k| @pages[k] = true }
      log('}} END IMPORT')
    end

    def import_nodes
      log('## import_nodes')

      @nodes = get_new_instances_from_repo(Node) do |node|
        rank = node.delete(:rank)
        identifiers = node.delete(:identifiers)
        @identifiers += identifiers.map { |ident| { identifier: ident, node_resource_pk: node[:resource_pk] } }
        unless rank.nil?
          rank = Rank.where(name: rank).first_or_create do |r|
            r.name = rank
            r.treat_as = Rank.guess_treat_as(rank)
          end
          node[:rank_id] = rank.id
        end
        if (ancestors = node.delete(:ancestors))
          ancestors.each do |anc|
            next if anc == node[:resource_pk]
            @ancestors << { node_resource_pk: node[:resource_pk], ancestor_resource_pk: anc, resource_id: @resource.id }
          end
        end
        # TODO: we should have the repository calculate the depth...
        # So, until we parse the WHOLE thing (at the source), we have to deal with this. Probably fair enough to include
        # it here anyway:
        node[:scientific_name] ||= "Unamed clade #{node[:resource_pk]}"
        node[:canonical_form] ||= "Unamed clade #{node[:resource_pk]}"
        # We do store the landmark ID, but this is helpful.
        node[:has_breadcrumb] = node.key?(:landmark)
      end
      if @nodes.empty?
        log('.. There were NO new nodes, skipping...')
        return
      end
      log(".. importing #{@nodes.size} Nodes")
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      Node.import(@nodes, on_duplicate_key_ignore: true, validate: false)
      Identifier.import(@identifiers, on_duplicate_key_ignore: true, validate: false)
      NodeAncestor.import(@ancestors, on_duplicate_key_ignore: true, validate: false)
      propagate_id(Node, resource: @resource, fk: 'parent_resource_pk', other: 'nodes.resource_pk',
                         set: 'parent_id', with: 'id')
      propagate_id(Identifier, resource: @resource, fk: 'node_resource_pk', other: 'nodes.resource_pk',
                               set: 'node_id', with: 'id')
      propagate_id(NodeAncestor, resource: @resource, fk: 'ancestor_resource_pk', other: 'nodes.resource_pk',
                                 set: 'ancestor_id', with: 'id')
      propagate_id(NodeAncestor, resource: @resource, fk: 'node_resource_pk', other: 'nodes.resource_pk',
                                 set: 'node_id', with: 'id')
    end

    def create_new_pages
      log('## create_new_pages')
      # CREATE NEW PAGES: TODO: we need to recognize DWH and allow it to have its pages assign the native_node_id to it,
      # regardless of other nodes. (Meaning: if a resource creates a weird page, the DWH later recognizes it and assigns
      # itself to that page, then the native_node_id should *change* to the DWH id.)
      Node.where(resource_pk: @nodes.map { |n| n[:resource_pk] }).select("id, page_id").find_each do |node|
        @node_id_by_page[node.page_id] = node.id
      end
      have_pages = Page.where(id: @node_id_by_page.keys).pluck(:id)
      missing = @node_id_by_page.keys - have_pages
      pages = missing.map { |id| { id: id, native_node_id: @node_id_by_page[id], nodes_count: 1 } }
      if pages.empty?
        log('.. There were NO new pages, skipping...')
        return
      end
      log(".. importing #{pages.size} Pages")
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      Page.import!(pages, on_duplicate_key_ignore: true)
      log('.. fixing counter_culture counts for Node...')
      Node.where(resource_id: @resource.id).counter_culture_fix_counts
    end

    def import_scientific_names
      log('## import_scientific_names')

      @names = get_new_instances_from_repo(ScientificName) do |name|
        status = name.delete(:taxonomic_status)
        status = "accepted" if status.blank?
        unless status.nil?
          name[:taxonomic_status_id] = get_tax_stat(status)
        end
        name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
        name[:italicized].gsub!(/, .*/, ", et al.") if name[:italicized] && name[:italicized].size > 200
      end
      num_bad = @names.select { |name| name[:page_id].nil? }.size
      if num_bad > 0
        puts "** WARNING: you've got #{num_bad} scientific_names with no page_id!"
        puts @names.select { |name| name[:page_id].nil? }.map { |n| n[:canonical_form] }.join('; ')
        @names.delete_if { |name| name[:page_id].nil? }
      end
      if @names.empty?
        log('.. There were NO new scientific names, skipping...')
        return
      end
      log(".. importing #{@names.size} ScientificNames")
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      ScientificName.import(@names, on_duplicate_key_ignore: true)
      propagate_id(ScientificName, resource: @resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                         set: 'node_id', with: 'id')
      # TODO: This doesn't ensure we're getting *preferred* scientific_name.
      propagate_id(Node, resource: @resource, fk: 'id',  other: 'scientific_names.node_id',
                         set: 'scientific_name', with: 'italicized')
      log('.. fixing counter_culture counts for ScientificName...')
      ScientificName.counter_culture_fix_counts
    end

    def import_vernaculars
      log('## import_vernaculars')

      @verns = get_new_instances_from_repo(Vernacular) do |name|
        name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
        name[:string] = name.delete(:verbatim)
        name.delete(:language_code_verbatim) # We don't use this.
        lang = name.delete(:language)
        # TODO: default language per resource?
        name[:language_id] = lang ? get_language(lang) : get_language(code: "eng", group_code: "en")
        name[:is_preferred_by_resource] = name.delete(:is_preferred)
      end
      if @verns.empty?
        log('.. There were NO new vernaculars, skipping...')
        return
      end
      log(".. importing #{@verns.size} Vernaculars")
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      Vernacular.import(@verns, on_duplicate_key_ignore: true)
      propagate_id(Vernacular, resource: @resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                         set: 'node_id', with: 'id')
      log('.. fixing counter_culture counts for ScientificName...')
      Vernacular.counter_culture_fix_counts
      # TODO: update preferred = true where page.vernaculars_count = 1...
      Vernacular.joins(:page).where(['pages.vernaculars_count = 1 AND vernaculars.is_preferred_by_resource = ? '\
        'AND vernaculars.resource_id = ?', true, @resource.id]).update_all(is_preferred: true)
    end

    def import_media
      log('## import_media')
      @media_by_page = {}
      @media_pks = []
      log('.. get media from repo...')
      @media = get_new_instances_from_repo(Medium) do |medium|
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
        medium[:license_id] ||= 1 # TEMP will look for source_url
        page_id = medium.delete(:page_id)
        @media_by_page[page_id] = medium[:resource_pk]
        @media_pks << medium[:resource_pk]
      end
      if @media.empty?
        log('.. There were NO new media, skipping...')
        return
      end
      log('.. import media...')
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      Medium.import(@media, on_duplicate_key_ignore: true)
      @media_id_by_pk = {}
      log('.. learn IDs...')
      Medium.where(resource_pk: @media_pks).select('id, resource_pk').find_in_batches.each do |group|
        group.each { |med| @media_id_by_pk[med.resource_pk] = med.id }
      end
      @contents = []
      @ancestry = {}
      log('.. learn Ancestry...')
      @naked_pages = {}
      Page.includes(:native_node).where(id: @media_by_page.keys).find_in_batches do |group|
        group.each do |page|
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
      log('.. build page contents...')
      @media_by_page.each do |page_id, medium_pk|
        # TODO: position. :(
        # TODO: trust...
        @contents << { page_id: page_id, source_page_id: page_id, position: 10000, content_type: 'Medium',
                       content_id: @media_id_by_pk[medium_pk] }
        if @naked_pages.key?(page_id)
          @naked_pages[page_id].assign_attributes(medium_id: @media_id_by_pk[medium_pk])
        end
        if @ancestry.key?(page_id)
          @ancestry[page_id].each do |ancestor_id|
            next if ancestor_id == page_id
            @contents << { page_id: ancestor_id, source_page_id: page_id, position: 10000, content_type: 'Medium',
              content_id: @media_id_by_pk[medium_pk] }
            if @naked_pages.key?(ancestor_id)
              @naked_pages[ancestor_id].assign_attributes(medium_id: @media_id_by_pk[medium_pk])
            end
          end
        end
      end
      log(".. import #{@contents.size} page contents...")
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      PageContent.import(@contents, on_duplicate_key_ignore: true)
      unless @naked_pages.empty?
        log(".. updating #{@naked_pages.values.size} pages with icons...")
        Page.import!(@naked_pages.values, on_duplicate_key_update: [:medium_id])
      end
      # Using the date here is not the best idea: :S
      PageContent.where(['created_at > ?', 1.day.ago]).counter_culture_fix_counts
    end

    def import_traits
      log('## import_traits')
      TraitBank::Admin.remove_for_resource(@resource) # TEMP!!!

      url = "#{Rails.configuration.repository_url}/resources/#{@resource.repository_id}/traits.json?"
      loop_over_pages(url, "traits") do |trait_data|
        trait = underscore_hash_keys(trait_data)
        import_trait(trait)
      end
    end

    def get_new_instances_from_repo(klass)
      type = klass.class_name.underscore.pluralize.downcase
      things = []
      url = "#{Rails.configuration.repository_url}/resources/#{@resource.repository_id}/#{type}.json?"
      loop_over_pages(url, type.camelize(:lower)) do |thing_data|
        thing = underscore_hash_keys(thing_data)
        yield(thing)
        begin
          things << thing.merge(resource_id: @resource.id)
        rescue
          debugger
          321
        end
      end
      things
    end

    def loop_over_pages(url_without_page, key)
      page = 1
      total_pages = 2 # Dones't matter YET... will be populated in a bit...
      while page <= total_pages
        url = "#{url_without_page}page=#{page}"
        log "<< #{url}"
        html_response = Net::HTTP.get(URI.parse(url))
        response = JSON.parse(html_response)
        total_pages = response["totalPages"]
        return unless response.key?(key) # Nothing returned.
        response[key].each do |data|
          yield(data)
        end
        page += 1
      end
    end

    def import_trait(trait)
      page_id = trait.delete(:page_id)
      debugger if page_id.nil?
      trait[:page] = @traitbank_pages[page_id] || add_page(page_id)
      trait[:object_page_id] = trait.delete(:association)
      trait.delete(:object_page_id) if trait[:object_page_id] == 0
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
      trait[:source] = trait.delete(:source_url)
      # The rest of the keys are "just right" and will work as-is:
      begin
        TraitBank.create_trait(trait.symbolize_keys)
      rescue Excon::Error::Socket => e
        begin
          TraitBank.create_trait(trait.symbolize_keys)
        rescue
          log "** ERROR: could not add trait:"
          log "** ID: #{trait[:resource_pk]}"
          log "** Page: #{trait[:page][:data][:page_id]}"
          log "** Predicate: #{trait[:predicate][:data][:uri]}"
        end
      end
    end

    def add_page(page_id)
      tb_page = TraitBank.create_page(page_id)
      tb_page = tb_page.first if tb_page.is_a?(Array)
      if Page.exists?(page_id)
        page = Page.find(page_id)
        parent_id = page.try(:native_node).try(:parent).try(:page_id)
        if parent_id
          parent = @traitbank_pages[page_id] || add_page(parent_id)
          parent = parent.first if parent.is_a?(Array)
          if parent_id == page_id
            log "** OOPS: we just tried to add #{parent_id} as a parent to itself!"
          else
            log "Adding parent #{parent_id} to page #{page_id}..."
            TraitBank.add_parent_to_page(parent, tb_page)
          end
        end
      else
        log "Trait attempts to use missing page: #{page_id}, ignoring links"
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

    # I AM NOT A FAN OF SQL... but this is **way** more efficient than alternatives:
    def propagate_id(klass, options = {})
      fk = options[:fk]
      set = options[:set]
      resource = options[:resource]
      with_field = options[:with]
      (o_table, o_field) = options[:other].split(".")
      sql = "UPDATE `#{klass.table_name}` t JOIN `#{o_table}` o ON (t.`#{fk}` = o.`#{o_field}` AND t.resource_id = ?) "\
            "SET t.`#{set}` = o.`#{with_field}`"
      clean_execute(klass, [sql, @resource.id])
    end

    def clean_execute(klass, args)
      clean_sql = klass.send(:sanitize_sql, args)
      klass.connection.execute(clean_sql)
    end

    def log(what)
      what = "[#{Time.now.strftime('%H:%M:%S')}] #{what}"
      Delayed::Worker.logger.info(what)
      puts what
    end
  end
end
