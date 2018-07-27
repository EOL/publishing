class Term::Importer
  attr_reader :knew, :skipped

  def initialize(options)
    @skip_known_terms = options[:skip_known_terms]
    @knew = 0
    @new_terms = {}
    @skipped = 0
    @terms = if @skip_known_terms
              get_existing_terms # TODO: we don't need to do this unless there are old terms we want to skip.
            else
              {}
            end
  end

  def from_hash(term)
    @knew += 1 if @terms.key?(term[:uri])
    next if @skip_known_terms && @terms.key?(term[:uri])
    if Rails.env.development? && term[:uri] =~ /wikidata\.org\/entity/ # There are many, many of these. :S
      @skipped += 1
      next
    end
    @term[term[:uri]] = true # Now it's "known"
    @new_terms[term[:uri]] = 1
    # TODO: section_ids
    term[:type] = term[:used_for] if term.key?(:used_for)
    # TODO: really, we should write these to CSV (or get CSV from the server) and import them like other traits.
    # That's a lot of work, though, so I'm skipping it for now. The cost is that it is REALLY SLOW, esp. when there's
    # more than a few dozen terms to import:
    TraitBank.create_term(term.merge(force: true))
  end

  def new_terms
    @new_terms.keys
  end

  def get_existing_terms
    Rails.cache.delete("trait_bank/terms_count/include_hidden")
    count = TraitBank::Terms.count(include_hidden: true)
    per = 2000
    pages = (count / per.to_f).ceil
    (1..pages).each do |page|
      terms = TraitBank::Terms.full_glossary(page, per, include_hidden: true).compact
      terms.map { |t| t[:uri] } .each { |uri| @terms[uri] = true }
    end
  end
end
