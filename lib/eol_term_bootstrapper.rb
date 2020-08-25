# This is meant to be "one-time-use-only" code to generate a "bootstrap" for the eol_terms gem, by
# reading all of the terms we have in neo4j and writing a YML file with all of that info in it.
#
# > EolTermBootstrapper.new('/path/to/output/yaml').create
class EolTermBootstrapper
  def initialize(filename)
    @terms_from_neo4j = []
    @uri_hashes = []
    @filename = filename
  end

  def create
    get_terms_from_neo4j
    populate_uri_hashes
    create_yaml
    report
  end

  def get_terms_from_neo4j
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
    @terms_from_neo4j.each do |term|
      term = correct_keys(term)
      # Yes, these lookups will slow things down. That's okay, we don't run this often... maybe only once!
      term['parent_uri'] = TraitBank::Terms.parent_of_term(term['uri'])
      term['synonym_of_uri'] = TraitBank::Terms.synonym_of_term(term['uri'])
      term['alias'] = nil # This will have to be done manually.
      @uri_hashes << term
    end
  end

  def correct_keys(term)
    hash = term.stringify_keys
    term.keys.each do |key|
      hash.delete(key) if key[0..4] == 'name_'
    end
    hash[]
  end

  def create_yaml
    File.open(@filename, 'w') do |file|
      file.write "# This file was automatically generated from the eol_website codebase using EolTermBootstrapper.\n"
      file.write "# You MAY edit this file as you see fit. You may remove this message if you care to.\n\n"
      file.write({ 'terms' => @uri_hashes }.to_yaml)
    end
  end

  def report
    puts "Done."
    lines = `wc #{@filename} | awk '{print $1;}'`.chomp
    puts "Wrote #{@uri_hashes.size} term hashes to `#{@filename}` (#{lines} lines)."
  end
end
