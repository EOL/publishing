# This is meant to be "one-time-use-only" code to generate a "bootstrap" for the eol_terms gem, by
# reading all of the terms we have in neo4j and writing a YML file with all of that info in it.
#
# > EolTermBootstrapper.new('/app/public/data/terms.yml').create # For example...
# Done.
# Wrote 3617 term hashes to `/app/public/data/terms.yml` (76321 lines).
# => nil
#
# And now you can download it from e.g. http://eol.org/data/terms.yml or http://beta.eol.org/data/terms.yml
class EolTermBootstrapper
  # Some parameters on Term nodes are auto-generated, and others are vesitgial, so we can ignore them:
  IGNORABLE_TERM_PARAMS =
    %w[distinct_page_count trait_row_count position section_ids is_ordinal id sections hide_from_dropdowns].freeze

  def initialize(filename = nil)
    @filename = filename
  end

  def create
    get_terms_from_neo4j
    populate_uri_hashes
    create_yaml
    report
  end

  def load
    get_terms_from_neo4j
    populate_uri_hashes
    reset_comparisons
    compare_with_gem
    create_new
    update_existing
    delete_extras
  end

  def get_terms_from_neo4j
    @terms_from_neo4j = []
    page = 0
    while data = TraitBank::Terms.full_glossary(page += 1)
      break if data.empty?
      @terms_from_neo4j << data # Uses less memory than #+=
    end
    @terms_from_neo4j.flatten! # Beacuse we used #<<
  end

  # neo4j format:
  # :attribution=>"",
  # :definition=>"a measure of specific growth rate",
  # :comment=>"",
  # :created_at=>"2019-01-15T21:00:41.000Z",
  # :force=>true,
  # :is_hidden_from_select=>false,
  # :is_hidden_from_overview=>false,
  # :is_hidden_from_glossary=>false,
  # :is_text_only=>false,
  # :is_verbatim_only=>false,
  # :ontology_source_url=>"",
  # :ontology_information_url=>"",
  # :position=>""
  # :name=>"%/month",
  # :name_[LANG_CODE]=>"%/month",   ... but we don't need to worry about these here.
  # :section_ids=>"",
  # :type=>"value",
  # :updated_at=>"2019-01-15T21:00:41.000Z",
  # :uri=>"http://eol.org/schema/terms/percentPerMonth",
  # :used_for=>"value",
  # ---
  # YAML format adds:
  #   parent_uri:
  #   synonym_of_uri:
  #   alias:
  def populate_uri_hashes
    @uri_hashes = []
    @terms_from_neo4j.each do |term|
      term = correct_keys(term)
      # Yes, these lookups will slow things down. That's okay, we don't run this often... maybe only once!
      # NOTE: yuo. This method accounts for nearly all of the time that the process requires. Alas.
      term['parent_uri'] = TraitBank::Terms.parent_of_term(term['uri'])
      term['synonym_of_uri'] = TraitBank::Terms.synonym_of_term(term['uri'])
      term['alias'] = nil # This will have to be done manually.
      @uri_hashes << term
    end
  end

  def correct_keys(term)
    hash = term.stringify_keys
    IGNORABLE_TERM_PARAMS.each do |ignored_key|
      hash.delete(ignored_key)
    end
    term.keys.each do |key_sym|
      key = key_sym.to_s
      hash.delete(key) if key[0..4] == 'name_'
    end
    hash
  end

  def create_yaml
    File.open(@filename, 'w') do |file|
      file.write "# This file was automatically generated from the eol_website codebase using EolTermBootstrapper.\n"
      file.write "# COMPILED: #{Time.now.strftime('%F %T')}\n"
      file.write "# You MAY edit this file as you see fit. You may remove this message if you care to.\n\n"
      file.write({ 'terms' => @uri_hashes }.to_yaml)
    end
  end

  def report
    puts "Done."
    lines = `wc #{@filename} | awk '{print $1;}'`.chomp
    puts "Wrote #{@uri_hashes.size} term hashes to `#{@filename}` (#{lines} lines)."
  end

  def reset_comparisons
    @new_uris = []
    @update_uris = []
    @extra_uris = []
  end

  def compare_with_gem
    seen_uris = {}
    @uri_hashes.each do |term_from_neo4j|
      seen_uris[term_from_neo4j['uri']] = true
      unless by_uri_from_gem.key?(term_from_neo4j['uri'])
        @extra_uris << term_from_neo4j['uri']
        next
      end
      @update_uris << term_from_neo4j unless by_uri_from_gem[term_from_neo4j['uri']] == term_from_neo4j
    end
    EolTerms.list.each do |term_from_gem|
      @new_uris << term_from_gem unless seen_uris.key?(term_from_gem['uri'])
    end
  end

  def by_uri_from_gem
    return @by_uri_from_gem unless @by_uri_from_gem.nil?
    @by_uri_from_gem = {}
    EolTerms.list.each { |term| @by_uri_from_gem[term['uri']] = term }
    @by_uri_from_gem
  end

  def create_new
    # TODO: Someday, it would be nice to do this by writing a CSV file and reading that. Much faster.
    @new_uris.each { |term| TraitBank::Term.create(term) }
  end

  def update_existing
    @update_uris.each { |term| TraitBank.(TraitBank.term(term['uri']), term) }
  end

  def delete_extras
    @extra_uris
  end
end
