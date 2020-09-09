# frozen_string_literal: true

# This is meant to be "one-time-use-only" code to generate a "bootstrap" for the eol_terms gem, by
# reading all of the terms we have in neo4j and writing a YML file with all of that info in it.
#
# > TermBootstrapper.new('/app/public/data/terms.yml').create # For example...
# Done.
# Wrote 3617 term hashes to `/app/public/data/terms.yml` (76321 lines).
# => nil
#
# And now you can download it from e.g. http://eol.org/data/terms.yml or http://beta.eol.org/data/terms.yml
#
# For testing purposes, remember that
#
# http://eol.org/schema/terms/extant is a parent of http://eol.org/schema/terms/conservationDependent
#
# And
#
# http://purl.obolibrary.org/obo/GO_0040011 is the synonym of http://www.owl-ontologies.com/unnamed.owl#Locomotion
class TermBootstrapper
  def initialize(filename = nil)
    @filename = filename
  end

  def create
    get_terms_from_neo4j
    populate_uri_hashes # NOTE: slow
    create_yaml
    report
  end

  # NOTE: this clears cache! It *must*, because there could be deltas that haven't been captured yet. BE AWARE!
  def load
    Rails.cache.clear
    get_terms_from_neo4j
    # This raises an exception if it finds any. You will have to deal with it yourself!
    check_for_case_duplicates
    populate_uri_hashes # NOTE: slow
    reset_comparisons
    compare_with_gem
    create_new
    update_existing
    delete_extras
  end

  def get_terms_from_neo4j
    @raw_terms_from_neo4j = []
    page = 0
    while data = TraitBank::Term.full_glossary(page += 1)
      break if data.empty?
      @raw_terms_from_neo4j << data # Uses less memory than #+=
    end
    @raw_terms_from_neo4j.flatten! # Beacuse we used #<<
  end

  def check_for_case_duplicates
    seen = {}
    @raw_terms_from_neo4j.each do |term|
      raise("DUPLICATE URI (case is different): #{term[:uri]} vs #{seen[term[:uri].downcase]}") if
        seen.key?(term[:uri].downcase)
      seen[term[:uri].downcase] = term[:uri]
    end
  end

  # NOTE: slow. See below.
  def populate_uri_hashes
    @terms_from_neo4j = []
    @raw_terms_from_neo4j.each do |term|
      term = correct_keys(term)
      # NOTE: Indeed, these two calls account for nearly *all* of the time that the #create process requires. Alas. This is OK.
      term['parent_uris'] = Array(TraitBank::Term.parents_of_term(term['uri']))
      term['synonym_of_uri'] = TraitBank::Term.synonym_of_term(term['uri'])
      term['alias'] = nil # This will have to be done manually.
      @terms_from_neo4j << term
    end
  end

  def correct_keys(term)
    hash = term.stringify_keys
    new_hash = {}
    EolTerms::Validator::VALID_FIELDS.each { |param| new_hash[param] = hash[param] if hash.key?(param) }
    new_hash
  end

  def create_yaml
    File.open(@filename, 'w') do |file|
      file.write "# This file was automatically generated from the eol_website codebase using TermBootstrapper.\n"
      file.write "# COMPILED: #{Time.now.strftime('%F %T')}\n"
      file.write "# You MAY edit this file as you see fit. You may remove this message if you care to.\n\n"
      file.write({ 'terms' => @terms_from_neo4j }.to_yaml)
    end
  end

  def report
    puts "Done."
    lines = `wc #{@filename} | awk '{print $1;}'`.chomp
    puts "Wrote #{@terms_from_neo4j.size} term hashes to `#{@filename}` (#{lines} lines)."
  end

  def reset_comparisons
    @new_terms = []
    @update_terms = []
    @uris_to_delete = []
  end

  def compare_with_gem
    seen_uris = {}
    @terms_from_neo4j.each do |term_from_neo4j|
      seen_uris[term_from_neo4j['uri'].downcase] = true
      unless by_uri_from_gem.key?(term_from_neo4j['uri'])
        @uris_to_delete << term_from_neo4j['uri']
        next
      end
      @update_terms << term_from_neo4j unless by_uri_from_gem[term_from_neo4j['uri']] == term_from_neo4j
    end
    EolTerms.list.each do |term_from_gem|
      @new_terms << term_from_gem unless seen_uris.key?(term_from_gem['uri'].downcase)
    end
  end

  def by_uri_from_gem
    return @by_uri_from_gem unless @by_uri_from_gem.nil?
    @by_uri_from_gem = {}
    EolTerms.list.each { |term| @by_uri_from_gem[term['uri']] = term }
    @by_uri_from_gem
  end

  def create_new
    @uri_ids ||= EolTerms.uri_ids
    # TODO: Someday, it would be nice to do this by writing a CSV file and reading that. Much faster. But I would prefer to
    # generalize the current Slurp class before attempting it.
    @new_terms.each do |term|
      TraitBank::Term.create(term)
    end
  end

  def update_existing
    @update_terms.each { |term| TraitBank::Term.update(TraitBank.term(term['uri']), term) }
  end

  def delete_extras
    # First you have to make sure they aren't related to anything. If they are, warn. But, otherwise, it should be safe to
    # delete them.
    @uris_to_delete.each do |uri|
      next if uri_has_relationships?(uri)
      TraitBank::Term.delete(uri)
    end
  end

  def uri_has_relationships?(uri)
    num =
      TraitBank.count_rels_by_direction(%Q{term:Term { uri: "#{uri.gsub(/"/, '""')}"}}, :outgoing) +
      TraitBank.count_rels_by_direction(%Q{term:Term { uri: "#{uri.gsub(/"/, '""')}"}}, :incoming)
    return false if num.zero?
    warn "NOT REMOVING TERM FOR #{uri}. It has #{num} relationships! You should check this manually and either add it to "\
         'the list or delete the term and all its relationships.'
    true
  end
end
