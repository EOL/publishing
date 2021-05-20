class ApiReconciliationController < ApplicationController
  skip_before_action :verify_authenticity_token

  ManifestType = Struct.new(:id, :name)
  MAX_LIMIT = 50

  class ValidationResult
    def initialize(valid, msg)
      @valid = valid
      @msg = msg
    end

    def valid?
      @valid
    end

    def message
      @msg
    end

    class << self
      def valid
        self.new(true, nil)
      end

      def invalid(msg)
        self.new(false, msg)
      end
    end
  end

  TYPE_TAXON = ManifestType.new("taxon", "Taxon")
  MANIFEST_TYPES = [TYPE_TAXON]

  def index
    if params[:queries]
      queries(JSON.parse(params[:queries]))
    else
      manifest
    end
  end

  def test
    @sample_query = {
      q1: {
        query: 'northern raccoon'
      }
    }
  end

  private
  # GET "/" -- service manifest 
  def manifest
    @types = MANIFEST_TYPES
    render :index, formats: :json
  end

  # GET "/?queries=...", POST "/" 
  def queries(qs)
    validation_result = validate_queries(qs)

    return bad_request(validation_result.message) unless validation_result.valid?

    result = qs.map do |k, v| 
      result = query(v)
      [k, result]
    end.to_h

    render json: result
  end

  def query(q)
    match = :text_start
    query_str = q['query']
    limit = [(q['limit'] || MAX_LIMIT), MAX_LIMIT].min

    result = Page.search(query_str, fields: %w[
      preferred_vernacular_strings^10 preferred_scientific_names^10 
      vernacular_strings scientific_name synonyms
    ], match: match, highlight: { tag: '' }, limit: limit)

    hash_results = result.hits.map.with_index do |hit, i|
      # First result is a confident match if 
      # 1) a search field matches the query exactly
      # 2) the next result has a lower score (or doesn't exist)
      page = result[i]
      score = hit['_score']
      highlight_strs = page.search_highlights.values.map { |v| v.downcase }

      confident_match = (
        i == 0 && 
        (result.length == 1 || result.hits[1]['_score'] < score) &&
        highlight_strs.include?(query_str.downcase)
      )

      { 
        id: "pages/#{page.id}", 
        name: page.scientific_name_string, 
        score: hit['_score'],
        type: [{ id: TYPE_TAXON.id, name: TYPE_TAXON.name }],
        match: confident_match
      }
    end

    { result: hash_results }
  end

  def bad_request(msg)
    render json: { error: msg }, status: :bad_request
  end

  def validate_queries(qs)
    return ValidationResult.invalid("queries must be a hash") unless qs.is_a? Hash

    qs.each do |k, v|
      return ValidationResult.invalid("'query' property missing for key #{k}") unless v['query'].present?
    end

    ValidationResult.valid
  end
end
