class Publishing::PubTraits
/read_data_  def self.import(resource, log, repo)
    log ||= Publishing::PubLog.new(resource)
    a_long_long_time_ago = 1202911078 # 10 years ago when this was written; no sense coding it.
    repo ||= Publishing::Repository.new(resource: resource, log: log, since: a_long_long_time_ago)
    new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
  end

  def import
    @log.log('import_traits')
    require 'csv'
    # TEMP!!! DELETEME (the remove_for_resource) ... you don't want to do this forever, when we have deltas.
    TraitBank::Admin.remove_for_resource(@resource)
    TraitBank.create_resource(@resource.id)
    trait_rows = []
    meta_rows = []
    trait_rows << Resource.trait_headers
    meta_rows << Resource.meta_headers
    read_data_type('traits', trait_rows, meta_rows)
    read_data_type('assocs', trait_rows, meta_rows)
    return if trait_rows.size <= 1
    save_files(trait_rows, meta_rows)
    slurp_traits
  end

  def save_files(trait_rows, meta_rows)
    @log.log("saving data (#{trait_rows.size - 1}) and all metadata (#{meta_rows.size - 1}, "\
             "total #{trait_rows.size + meta_rows.size - 2})")
    CSV.open(@resource.traits_file, 'w') { |csv| trait_rows.each { |row| csv << row } }
    CSV.open(@resource.meta_traits_file, 'w') { |csv| meta_rows.each { |row| csv << row } }
  end

  def slurp_traits
    TraitBank::Slurp.load_csvs(@resource)
    @resource.remove_traits_files
    @log.log("Completed.")
  end

  def grab_metadata(trait, meta_rows)
    meta = trait.delete(:metadata)
    meta.each do |m_datum_camel|
      meta_row = []
      m_datum = Publishing::Repository.underscore_hash_keys(m_datum_camel)
      meta_rows.first.each do |header|
        if header == :trait_eol_pk
          meta_row << trait[:eol_pk]
        else
          meta_row << m_datum[header]
        end
      end
      meta_rows << meta_row
    end
  end

  def read_data_type(type, trait_rows, meta_rows)
    @log.log("read_#{type}")
    path = "resources/#{@resource.repository_id}/#{type}.json?"
    @repo.loop_over_pages(path, type) do |datum|
      row = []
      trait_rows.first.each do |header|
        row << datum[header]
      end
      trait_rows << row
      grab_metadata(datum, meta_rows)
    end
  end
end
