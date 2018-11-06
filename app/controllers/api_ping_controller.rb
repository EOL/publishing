class ApiPingController < LegacyApiController
  def index
    respond_to do |format|
      success = { 'response' => { 'message' => 'Success' } }
      format.json { render json: success }
      format.xml { render xml: success.to_xml }
    end
  end
end
