class ApiReconciliationController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    if params[:queries]
      reconcile(JSON.parse(params[:queries]))
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
    @types = ReconciliationResult::MANIFEST_TYPES
    render :index, formats: :json
  end

  # GET "/?queries=...", POST "/" 
  def reconcile(qs)
    validated_queries = ReconciliationResult::ValidatedQueries.new(qs)

    return bad_request(validation_result.message) unless validated_queries.valid?

    render json: ReconciliationResult.new(validated_queries).to_h
  end

  def bad_request(msg)
    render json: { error: msg }, status: :bad_request
  end
end

