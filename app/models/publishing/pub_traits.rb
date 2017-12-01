class Publishing::PubTraits
  def self.import(resource, log, repo)
    Publishing::PubTraits.new(resource, log, repo).import
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
    trait_rows = []
    meta_rows = []
    trait_rows << %i[page_id scientific_name resource_pk predicate sex lifestage statistical_method source
      target_page_id target_scientific_name value_uri value_literal value_num units]
    meta_rows << %i[trait_resource_pk predicate value_literal value_num value_uri units sex lifestage
      statistical_method source]
    @log.log('read_traits')
    path = "resources/#{@resource.repository_id}/traits.json?"
    @repo.loop_over_pages(path, "traits") do |trait|
      row = []
      trait_rows.first.each do |header|
        row << trait[header]
      end
      trait_rows << row
      meta = trait.delete(:metadata)
      meta.each do |m_datum_camel|
        meta_row = []
        m_datum = Publishing::Repository.underscore_hash_keys(m_datum_camel)
        meta_rows.first.each do |header|
          if header == :trait_resource_pk
            meta_row << trait[:resource_pk]
          else
            meta_row << m_datum[header]
          end
        end
      end
      meta_rows << meta_row
    end
    @log.log('read_associations')
    path = "resources/#{@resource.repository_id}/assocs.json?"
    @repo.loop_over_pages(path, "assocs") do |assoc|
      row = []
      trait_rows.first.each do |header|
        row << assoc[header]
      end
      trait_rows << row
      meta_row = []
      meta = assoc_data.delete(:metadata)
      meta_rows.first do |header|
        if header == :trait_resource_pk
          meta_row << assoc[:resource_pk]
        else
          meta_row << meta[header]
        end
      end
      meta_rows << meta_row
    end
    return if trait_rows.size <= 1
    @log.log("slurping traits and associations (#{trait_rows.size - 1}) and all metadata (#{meta_rows.size - 1}, "\
      "total #{trait_rows.size + meta_rows.size - 2})")
    traits_file = Rails.public_path.join("traits_#{@resource.id}.csv")
    meta_traits_file = Rails.public_path.join("meta_traits_#{@resource.id}.csv")
    CSV.open(traits_file, 'w') { |csv| trait_rows.each { |row| csv << row } }
    CSV.open(meta_traits_file, 'w') { |csv| meta_rows.each { |row| csv << row } }
    count = TraitBank.slurp_traits(@resource.id)
    @log.log("Created #{count} associations (including metadata).")
    @log.log("Keeping: #{traits_file}.")
    @log.log("Keeping: #{meta_traits_file}.")
    # File.unlink(traits_file) if File.exist?(traits_file)
    # File.unlink(meta_traits_file) if File.exist?(meta_traits_file)
  end
end
