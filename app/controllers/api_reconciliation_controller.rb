class ApiReconciliationController < ApplicationController
  skip_before_action :verify_authenticity_token

  DATA_DIR = Rails.application.root.join('config', 'api_reconciliation')
  QUERY_SCHEMA_PATH = DATA_DIR.join('query_schema.json')
  QUERY_SCHEMA = JSONSchemer.schema(QUERY_SCHEMA_PATH)

  def index
    if params[:queries]
      reconcile(JSON.parse(params[:queries]))
    elsif params[:extend]
      get_properties(JSON.parse(params[:extend]))
    else
      manifest
    end
  end

  # property typeahead, basically
  def suggest_properties
    prefix = (params[:prefix] || '').downcase
    cursor = params[:cursor] || 0

    matches = Reconciliation::PropertyType::ALL.select do |prop|
      prop.id.starts_with?(prefix) || prop.name.starts_with?(prefix)
    end

    result = matches[cursor..] || []
    respond(
      result: result.map do |prop| 
        { 
          id: prop.id, 
          name: prop.name, 
          description: prop.description 
        }
      end
    )
  end

  # list properties for given entity type (we only have one, 'taxon')
  def propose_properties
    type = params.require(:type)
    limit = params[:limit]&.to_i

    return bad_request("invalid limit value: #{limit}") if limit && limit < 1

    if type == Reconciliation::Result::TYPE_TAXON.id
      properties = Reconciliation::PropertyType::ALL.map { |pt| pt.to_h }
    else
      properties = []
    end

    limited_properties = limit.nil? ? properties : properties.take(limit)

    result = {
      type: type,
      properties: limited_properties
    } 

    result[:limit] = limit unless limit.nil?

    respond(result)
  end

  def test
    @sample_query = {
      q1: {
        query: 'northern raccoon',
        properties: [
          {
            pid: 'ancestor',
            v: [
              { id: "pages/1642", name: "Mammalia" },  
              "carnivores"
            ]
          },
          {
            pid: 'rank',
            v: 'species'
          }
        ]
      }
    }
  end

  def test_extend
    @sample_query = {
      ids: ['pages/328598'],
      properties: [
        { id: 'rank' },
        { id: 'ancestor' }
      ]
    }
  end

  private
  # GET "/" -- service manifest 
  def manifest
    # This is here instead of in a view file b/c I don't think it's possible to use the :callback option with views
    res = Jbuilder.new do |json|
      json.versions ["0.2"]
      json.name t("page_title")
      json.identifierSpace reconciliation_id_space_url
      json.schemaSpace reconciliation_schema_space_url

      json.defaultTypes Reconciliation::Result::MANIFEST_TYPES do |type|
        json.id type.id
        json.name type.name
      end

      json.view do
        json.url "https://eol.org/{{id}}"
      end

      json.suggest do
        json.property do
          json.service_url api_reconciliation_url
          json.service_path "/properties/suggest"
        end
      end

      json.extend do
        json.propose_properties do
          json.service_url api_reconciliation_url
          json.service_path "/properties/propose"
        end

        json.property_settings Reconciliation::PropertySettingType::ALL.each do |setting|
          json.default setting.default
          json.type setting.type
          json.label setting.label
          json.name setting.name
          json.help_text setting.help_text
        end
      end
    end.target!

    respond res
  end

  # GET "/?queries=...", POST "/" 
  def reconcile(qs)
    unless QUERY_SCHEMA.valid?(qs)
      first_error = QUERY_SCHEMA.validate(qs).next
      return bad_request("Invalid attribute or value: #{first_error["pointer"]}")
    end

    respond Reconciliation::Result.new(qs).to_h
  end

  def bad_request(msg)
    render json: { error: msg }, status: :bad_request
  end

  def get_properties(json)
    query = nil

    begin
      query = Reconciliation::DataExtensionQuery.new(json)
    rescue ArgumentError, TypeError => e # TODO: consider using a schema as above to return more helpful messages
      return bad_request(e.message)
    end

    rows = Reconciliation::DataExtensionResult.new(query).to_h
    meta = query.properties.map(&:to_h)

    respond({
      meta: meta,
      rows: rows
    })
  end

  def respond(json)
    if params[:callback].present?
      render json: json, callback: params[:callback] # JSONP, required by OpenRefine
    else
      render json: json
    end
  end
end


