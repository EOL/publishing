class Publishing
  attr_accessor :resource, :resources, :log, :pages, :run, :last_run_at, :since, :nodes, :ancestors, :identifiers,
    :names, :verns, :node_id_by_page, :traits, :traitbank_pages, :traitbank_suppliers, :traitbank_terms, :tax_stats,
    :languages, :licenses

  def self.start
    instance = self.new
    instance.start
  end

  def initialize
    @resource = nil
    @pub_log = Publishing::PubLog.new(nil)
    @log = nil
    @repo = nil
    @resources = []
    @page_ids = Set.new
    reset_resource # Not strictly required, but helps for debugging.
  end

  def start
    @pub_log.log("Starting import run...")
    get_import_run
    get_resources
    import_terms
    return nil if @resources.empty?
    @resources.each do |resource|
      @resource = resource
      @log = Publishing::PubLog.new(@resource)
      @repo = Publishing::Repository.new(resource: @resource, log: @log, since: @since)
      begin
        import_resource
        @log.complete
      rescue => e
        debugger
        @log.fail(e)
      end
    end
    # TODO: these logs end up attatched to a resource. They shouldn't be. ...Not sure where to move them, though.
    richness = RichnessScore.new
    # Note: this is quite slow, but searches won't work without it. :S
    if @page_ids.empty?
      # TODO: nononono, we need to mark ALL affected pages, not just new ones. EVERY class should return a list of
      # page_ids, and this must always run...
      @pub_log.log('No pages; skipping indexing.')
    else
      pages = Page.where(id: @page_ids).includes(:occurrence_map)
      @pub_log.log('score_richness_for_pages')
      @pub_log.log('pages.reindex')
      pages.reindex
    end
    Rails.cache.clear
    @pub_log.log('All Harvests Complete, stopping.', cat: :ends)
    @run.update_attribute(:completed_at, Time.now)
  end

  def get_import_run
    last_run = ImportRun.completed.last
    # NOTE: We use the CREATED time! We want all new data as of the START of the import. In pracice, this is less than
    # perfect... ideally, we would want a start time for each resource... but this should be adequate for our
    # purposes.
    @last_run_at = (last_run&.created_at || 10.years.ago).to_i
    @run = ImportRun.create
  end

  def get_resources
    @pub_log.log("Getting updated resources...")
    # If there are only a handful of resources, we've just created the DB and the max created_at is useless.
    path = "resources.json?"
    repo = Publishing::Repository.new(log: @pub_log, since: @last_run_at)
    repo.loop_over_pages(path, "resources") do |resource|
      resource[:repository_id] = resource.delete(:id)
      partner = resource.delete(:partner)
      # NOTE: resources that have no associated partner are PURELY test data in the repository database:
      if partner.nil?
        @pub_log.log("!! WARNING: **SKIPPING** resource #{resource[:name]} (#{resource[:repository_id]}): "\
          "no partner defined!", cat: :warns)
        next
      end
      partner[:repository_id] = partner.delete(:id)
      partner = find_and_update_or_create(Partner, partner)
      resource[:partner_id] = partner.id
      resource = find_and_update_or_create(Resource, resource)
      @pub_log.log("Will import resource: #{resource[:name]}")
      @resources << resource
    end
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
    @names = []
    @verns = []
    @traits = []
    @traitbank_pages = {}
    @traitbank_suppliers = {}
    @traitbank_terms = {}
    @tax_stats = {}
    @licenses = {}
    @since = (@resource&.import_logs&.successful&.any? ?
      @resource.import_logs.successful.last.created_at :
      10.years.ago).to_i
  end

  # TODO: extract the innards to a class, let Publishing just be the manager.
  def import_resource
    @log.log("Importing Resource: #{@resource.name} (#{@resource.id})")
    reset_resource
    # TODO: All ipmorts s/ return a list of affected pages.
    pub_nodes = Publishing::PubNodes.new(@resource, @log, @repo)
    ids = pub_nodes.import
    @page_ids += ids
    Publishing::PubScientificNames.import(@resource, @log, @repo)
    Publishing::PubVernaculars.import(@resource, @log, @repo)
    Publishing::PubMedia.import(@resource, @log, @repo)
    Publishing::PubTraits.import(@resource, @log, @repo)
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
    @pub_log.log("Importing terms...")
    terms = get_existing_terms # TODO: we don't need to do this unless there are new terms.
    knew = 0
    new_terms = 0
    skipped = 0
    path = "terms.json?per_page=1000&"
    repo = Publishing::Repository.new(log: @pub_log, since: @last_run_at)
    repo.loop_over_pages(path, "terms") do |term|
      knew += 1 if terms.key?(term[:uri])
      next if terms.key?(term[:uri])
      if Rails.env.development? && term[:uri] =~ /wikidata\.org\/entity/ # There are many, many of these. :S
        skipped += 1
        next
      end
      @pub_log.log("++ New term: #{term[:uri]}") if terms.size > 1000 # Don't bother saying if we didn't have any at all!
      new_terms += 1
      # TODO: section_ids
      term[:type] = term[:used_for]
      TraitBank.create_term(term.merge(force: true))
    end
    @pub_log.log("Finished importing terms: #{new_terms} new, #{knew} known, #{skipped} skipped.")
  end

  # The following methods can be removed when terms are capable of CSV import:

  def import_trait(trait)
    page_id = trait.delete(:page_id)
    if page_id.nil?
      @log.log("Skipping trait with no page_id: #{trait.inspect}", cat: :warns)
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
      # TODO: this call to class method kinda stinks... is it needed?
      md = Publishing::Repository.underscore_hash_keys(m_d)
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
        @log.log("WARNING: could not add trait with ID: #{trait[:resource_pk]} Page: "\
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
          @log.log("Skipped adding #{parent_id} as a parent to #{page_id}: #{result[:message]}", cat: :warns)
        end
      end
    else
      @log.log("Trait attempts to use missing page: #{page_id}, ignoring links", cat: :warns)
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
        @log.log("** WARNING: Failed to set property on term... #{e.message}")
        @log.log('** This seems to occur with some bad trait data (passing in hashes instead of strings)')
      end
    @traitbank_terms[uri] = term
  end
end
