class ContentPartnerApi
  @schedular_uri = ENV['schedular_ip']
  @storage_uri = ENV['storage_ip']
  
  def self.add_content_partner?(params, current_user_id)
    logo = params[:logo].nil? ? File.new(DEFAULT_CONTENT_PARTNER_LOGO, 'rb') : params[:logo]
    begin
      #TODO: change base uri to send to storage layer first and only when you get logo path back send all info to (logo path + info) schedular
      logo_request = RestClient::Request.new(
        :method => :post,
        :url => "#{@storage_uri}/contentPartners",
        :payload => { logo: logo }
      )
      logo_response = logo_request.execute
      logo_path = logo_reponse 
#       
      c=o
      request =RestClient::Request.new(
        :method => :post,
        :url => "#{@schedular_uri}/contentPartners",
        :payload => { name: params[:name], description: params[:description], url: params[:url], abbreviation: params[:abbreviation], logo: logo, logoPath: "path" }
      )
      # debugger
      response = request.execute
      ContentPartnerUser.create(user_id: current_user_id , content_partner_id: response.body.to_i)
      true
    rescue => e
      false
    end
  end
  
  def self.update_content_partner?(content_partner_id, params)
    logo = params[:logo].nil? ? File.new(DEFAULT_CONTENT_PARTNER_LOGO, 'rb') : params[:logo]
    begin
      request =RestClient::Request.new(
        :method => :post,
        :url => "#{@schedular_uri}/contentPartners/#{content_partner_id}",
        :payload => { name: params[:name], description: params[:description], url: params[:url], abbreviation: params[:abbreviation], logo: logo }
      )
      response = request.execute
      true
    rescue => e
      false
    end
  end
  
  def self.get_content_partner(ids)
    begin
      request =RestClient::Request.new(
        :method => :get,
        :url => "#{@schedular_uri}/contentPartners?ids=#{ids}"
      )
      response = JSON.parse(request.execute)
    rescue => e
      nil
    end
  end
  
end


