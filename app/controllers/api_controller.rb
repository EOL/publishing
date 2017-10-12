class ApiController < ApplicationController
  skip_before_filter :verify_authenticity_token  
  before_filter :set_default_format_to_xml
  before_filter :get_api_method, except: [ :render_test_response ]
  
  def pages
  end
  
  def render_test_response
    code = params[:code] || "Sorry, there was a problem"
    code = JSON.pretty_generate(JSON.parse(code)) if code.is_json?
    respond_to do |format|
      format.js do
        render partial: "api/render_test_response", locals: { code: code }
      end
    end
  end
  
  def default_render
    # if this api_method is blank, and error should already have been rendered
    return if @api_method.blank?
    if Rails.env.development? || Rails.env.test_dev?
      @json_response = @api_method.call(params)
    else
      begin
        @json_response = @api_method.call(params)
      rescue ActiveRecord::RecordNotFound => e
        return render_error(e.message, 404)
      rescue => e
        
        return render_error('Sorry, there was a problem')
      end
    end

    # return the JSON object generated above, OR
    # render the default (or custom) partial for this method: e.g. api/search_1_0.xml.builder
    respond_to do |format|
      if @api_method::TEMPLATE
        xml_template = @api_method::TEMPLATE
      else
        xml_template = "api/#{params[:action]}_#{@api_method::VERSION.tr('.', '_')}"
      end
      format.xml { render template: xml_template, layout: false }
      format.json { render json: @json_response, callback: params[:callback] }
    end
  end
  
  def get_api_method
    begin
      # load the parent module (e.g. EOL::Api::Pages) to get the default version
      method_class = "Api::#{params[:action].camelize}".constantize
    rescue => e
      render_error("Invalid method: #{params[:action]}")
      return nil
    end
    
    begin
      # load the proper version of the API method (e.g. EOL::Api::Pages::V0_0)
      params[:version] ||= method_class::DEFAULT_VERSION
      @api_method = "#{method_class}::V#{params[:version].tr('.', '_')}".constantize
    rescue => e
      render_error("Invalid version: #{params[:version]}")
      return nil
    end
    return @api_method

    
  end
  
  def render_error(error_message, status_code = 500)
    # default response for all API errors, with XML or JSON repsonses
    respond_to do |format|
      format.xml { render(partial: 'error', locals: { error: error_message }, status: status_code) }
      format.json { render(json: [ error: error_message ], callback: params[:callback], status: status_code ) }
      # API docs might have an error too, but in that case raise to get the default HTML error handling
      format.html { raise }
    end
  end

  def set_default_format_to_xml
    # all APIs return XML by default when no extension is given
    request.format = "xml" unless params[:format]
  end
  

end