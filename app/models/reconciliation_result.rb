class ReconciliationResult
  ManifestType = Struct.new(:id, :name)
  TYPE_TAXON = ManifestType.new("taxon", "Taxon")
  MANIFEST_TYPES = [ReconciliationResult::TYPE_TAXON]
  MAX_SCORE = 100
  INEXACT_TOP_SCORE = 75
  MIN_NAME_SCORE = 50

  def initialize(validated_queries)
    raise TypeError, "queries must be valid" unless validated_queries.valid?
    @raw_queries = validated_queries.queries
    build_results
  end

  # TODO: use JSON schema for validation?
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
    PROPERTY_IDS = ['ancestor']

    class PageQuery
      attr_reader :query_string, :searchkick_query

      def initialize(query_string, limit)
        @query_string = query_string
        @searchkick_query = build_searchkick_query
        @limit = [limit || MAX_LIMIT, MAX_LIMIT].min
      end

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

    attr_reader :key, :query_string, :searchkick_query

    MAX_LIMIT = 50
    def initialize(key, raw_query)
      @key = key
      @main_query = PageQuery.new(raw_query['query'], raw_query['limit'])
      build_property_queries(raw_query) # sets @property_queries and @property_entities
    end

    def query_string
      @main_query.query_string
    end

    def searchkick_query
      @main_query.searchkick_query
    end

    def all_searchkick_queries
      [searchkick_query] # TODO: Placeholder
    end

    def result_hash
      return @result_hash if @result_hash
      return {} if searchkick_query.empty?
      
      best_match = searchkick_query.first
      highlight_strs = best_match.search_highlights.values.map { |v| v.downcase }
      best_score_abs = highlight_strs.include?(query_string.downcase) ? MAX_SCORE : INEXACT_TOP_SCORE
      best_score_rel = searchkick_query.hits.first['_score']
      worst_score_rel = searchkick_query.hits.last['_score']
      rel_range = best_score_rel - worst_score_rel
      abs_range = best_score_abs - MIN_NAME_SCORE
      abs_rel_ratio = rel_range > 0 ? abs_range * 1.0 / rel_range : 0 # 0 is a sentinel value, won't be used in calculations

      hash_results = searchkick_query.hits.map.with_index do |hit, i|
        # First result is a confident match if 
        # 1) a search field matches the query exactly (best_score_abs == MAX_SCORE)
        # 2) the next result has a lower score (or doesn't exist)
        page = searchkick_query[i]
        score_rel = hit['_score']
        score_abs = abs_rel_ratio > 0 ? (score_rel - worst_score_rel) * abs_rel_ratio + MIN_NAME_SCORE : best_score_abs

        confident_match = (
          i == 0 && 
          (searchkick_query.length == 1 || searchkick_query.hits[1]['_score'] < score_rel) &&
          best_score_abs == MAX_SCORE
        )

        { 
          id: "pages/#{page.id}", 
          name: page.scientific_name_string, 
          score: score_abs,
          type: [{ id: TYPE_TAXON.id, name: TYPE_TAXON.name }],
          match: confident_match
        }
      end

      @result_hash = { result: hash_results }
    end

    private
    def build_property_queries(raw_query)
      @property_queries = {}
      @property_entities = {}

      # only 'ancestor' supported currently
      (raw_query['properties'] || []).each do |property|
        id = property['pid'] 

        next unless PROPERTY_IDS.include?(id) # TODO: how to handle? Is skipping ok?

        @property_queries[id] ||= []
        @property_entities[id] ||= []

        values = property['v']

        values.each do |v|
          if v.is_a? Hash
            @property_entities[id] << v
          else # it's a string, or should be
            @property_queries[id] << PageQuery.new(v, nil) # TODO: each property type needs its own handler
          end
        end
      end
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
