class ApiReconciliationController < ApplicationController
  ManifestType = Struct.new(:name, :description)

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

  MANIFEST_TYPES = [
    ManifestType.new("page", "A representation of a taxon on EOL")
  ]

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
    render :index
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
    result = Page.search(q['query'])
    result.hits.map.with_index do |hit, i|
      { 
        id: "pages/#{hit["_id"]}", 
        name: result[i].scientific_name, 
        score: hit["_score"],
        type: "page",
        match: true
      }
    end
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
