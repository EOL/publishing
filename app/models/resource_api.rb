class ResourceApi
  @base_schedular_uri = 'http://localhost:8084/scheduler'
  # @base_schedular_uri = 'http://172.16.0.161:80/scheduler'
  @base_storage_uri = 'http://localhost:8010/eol/archiver'

  def self.add_resource?(params, content_partner_id)
    # resource_data_set = params[:path]
    if params[:type]=="file"
       input_file = params[:path].tempfile
       file_name = params[:path].original_filename
       resource_data_set_file = Tempfile.new("#{file_name}")
       resource_data_set_file.write(input_file.read)
       params[:path]=""
    end
    # resource_params = params.except!(:resource_data_set).to_json_with_active_support_encoder  
    resource_params = params
    
    begin
      request =RestClient::Request.new(
        :method => :post,
        :url => "#{@base_schedular_uri}/#{content_partner_id}/resources",
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
          },
        :payload=> resource_params.to_json
      )
      response_scheduler = request.execute
      resource_id = response_scheduler.body
      if params[:type]=="file"
        begin
          resource_data_set_file.seek 0
          request =RestClient::Request.new(
            :method => :post,
            :url => "#{@base_storage_uri}/uploadResource/#{resource_id}/1",
            :payload => {resId: resource_id, file: resource_data_set_file, isOrg: 1 }
          )
        response_storage = request.execute
        resource_id
        rescue => e
          debugger
          nil
        end
        if(response_storage)
          params[:path]="/eol_workspace/resources/#{resource_id}/"
       # params[:id]=resource_id
          resource_params = params
          begin
            request =RestClient::Request.new(
              :method => :post,
              :url => "#{@base_schedular_uri}/#{content_partner_id}/resources/#{resource_id}",
              headers: {
                'Accept' => 'application/json',
                'Content-Type' => 'application/json'
                },
              :payload=> resource_params.to_json
            )
            response = request.execute
            resource_id
          rescue => e
            debugger
            nil
          end
        end
      end
      resource_id
    rescue => e
      debugger
      nil
    end
    
  end
  
  def self.update_resource?(params, content_partner_id,resource_id)
    if params[:type]=="file" && !params[:path].nil?
      resource_data_set_file = params[:path].tempfile
      params[:path]=""
      begin
        request =RestClient::Request.new(
          :method => :post,
          :url => "#{@base_storage_uri}/uploadResource/#{resource_id}/1",
          :payload => {resId: resource_id, file: resource_data_set_file, isOrg: 1 }
        )
        response_storage = request.execute
        resource_id
      rescue => e
        nil
      end
      if(response_storage)
        params[:path]="/eol_workspace/resources/#{resource_id}/"
      end
    end
    resource_params = params
    begin
      request =RestClient::Request.new(
        :method => :post,
        :url => "#{@base_schedular_uri}/#{content_partner_id}/resources/#{resource_id}",
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
          },
        :payload=> resource_params.to_json
      )
      response = request.execute
      resource_id
    rescue => e
      nil
    end
  end
  
  def self.get_resource(content_partner_id, resource_id)
    begin
      request =RestClient::Request.new(
        :method => :get,
        #:url => "#{@base_uri}/contentPartners?ids=#{ids}"
        :url => "#{@base_schedular_uri}/#{content_partner_id}/resources/#{resource_id}"
      )
      response = JSON.parse(request.execute)
    rescue => e
      nil
    end
  end
  
   def self.get_resource_using_id(resource_id)
    begin
      request =RestClient::Request.new(
        :method => :get,
        :url => "#{@base_schedular_uri}/resources/#{resource_id}"
      )
      response = JSON.parse(request.execute)
    rescue => e
      nil
    end
  end
  
  # def self.get_content_partnerid_using_resourceid(resource_id)
    # begin
      # request =RestClient::Request.new(
        # :method => :get,
        # :url => "#{@base_schedular_uri}/resources/#{resource_id}/contentPartner"
      # )
      # response = JSON.parse(request.execute)
    # rescue => e
      # nil
    # end
  # end
  
end

