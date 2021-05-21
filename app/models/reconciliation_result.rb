class ReconciliationResult
  ManifestType = Struct.new(:id, :name)
  TYPE_TAXON = ManifestType.new("taxon", "Taxon")
  MANIFEST_TYPES = [ReconciliationResult::TYPE_TAXON]

  def initialize(validated_queries)
    raise TypeError, "queries must be valid" unless validated_queries.valid?
    @raw_queries = validated_queries.queries
    build_results
  end

  class ValidatedQueries
    attr_accessor :queries

    def initialize(queries)
      @queries = queries
      @validation = validate(queries)
    end

    def valid?
      @validation.valid
    end

    def message
      @validation.message
    end

    private
    ValidationResult = Struct.new(:valid, :message)

    def validate(queries)
      return ValidationResult.new(false, "queries must be a hash") unless queries.is_a? Hash

      queries.each do |k, v|
        return ValidationResult.new(false, "'query' property missing for key #{k}") unless v['query'].present?
      end

      ValidationResult.new(true, nil)
    end
  end

  def to_h
    @queries.map { |q| [q.key, q.result_hash] }.to_h
  end

  private
  class Query
    attr_reader :key, :query_string, :limit, :searchkick_query
    MAX_LIMIT = 50

    def initialize(key, raw_query)
      @key = key
      @query_string = raw_query['query']
      @limit = [(raw_query['limit'] || MAX_LIMIT), MAX_LIMIT].min
      @searchkick_query = build_searchkick_query
    end

    def result_hash
      return @result_hash if @result_hash

      hash_results = @searchkick_query.hits.map.with_index do |hit, i|
        # First result is a confident match if 
        # 1) a search field matches the query exactly
        # 2) the next result has a lower score (or doesn't exist)
        page = @searchkick_query[i]
        score = hit['_score']
        highlight_strs = page.search_highlights.values.map { |v| v.downcase }

        confident_match = (
          i == 0 && 
          (@searchkick_query.length == 1 || @searchkick_query.hits[1]['_score'] < score) &&
          highlight_strs.include?(@query_string.downcase)
        )

        { 
          id: "pages/#{page.id}", 
          name: page.scientific_name_string, 
          score: hit['_score'],
          type: [{ id: TYPE_TAXON.id, name: TYPE_TAXON.name }],
          match: confident_match
        }
      end

      @result_hash = { result: hash_results }
    end

    private
    def build_searchkick_query
      match = :text_start

      Page.search(
        @query_string, 
        fields: %w[
          preferred_vernacular_strings^2 preferred_scientific_names^2 
          vernacular_strings scientific_name synonyms
        ], 
        match: match, 
        includes: [{ native_node: { node_ancestors: :ancestor } }],
        highlight: { tag: '' }, 
        limit: @limit,
        execute: false
      )
    end
  end

  def build_results
    @queries = @raw_queries.map { |k, v| Query.new(k, v) }
    execute_queries
  end

  def execute_queries
    Searchkick.multi_search(@queries.map { |q| q.searchkick_query })
  end
end
