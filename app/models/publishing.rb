class Publishing
  attr_accessor :resource, :resources, :log, :pages, :run, :last_run_at, :since, :nodes, :ancestors, :identifiers,
    :names, :verns, :traits, :traitbank_pages, :traitbank_suppliers, :traitbank_terms, :tax_stats,
    :languages, :licenses

  def self.sync
    instance = self.new
    instance.sync
  end

  def initialize
    @resource = nil
    @pub_log = Publishing::PubLog.new(nil)
    @log = nil
    @repo = nil
    @resources = []
    @page_ids = Set.new
    @since = (@resource&.import_logs&.successful&.any? ?
      @resource.import_logs.successful.last.created_at :
      10.years.ago).to_i
  end

  def sync
    abort_if_already_running
    begin
      @pub_log.log("Syncing with repository...")
      get_import_run
      get_resources
      import_terms
      @pub_log.log('Sync with repository complete.', cat: :ends)
      @run.update_attribute(:completed_at, Time.now)
    ensure
      ImportLog.all_clear!
    end
  end

  def abort_if_already_running
    if (info = ImportLog.already_running?)
      puts info
      raise('ABORTED.')
    end
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
      @pub_log.log("New/updated resource: #{resource[:name]}")
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

  # The following method can be removed when terms are capable of CSV import:
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
