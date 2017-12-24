class ContentPartners::ResourcesController < ContentPartnersController
  
  def new
    @resource = Resource.new
  end
  
  def create
    resource_params = { name: params[:resource][:name], origin_url: params[:resource][:origin_url],uploaded_url: params[:resource][:uploaded_url],
                        path: params[:resource][:path],type: params[:resource][:type],harvest_frequency: params[:resource][:harvest_frequency],
                        dataset_license: params[:resource][:dataset_license],
                        dataset_rights_holder: params[:resource][:dataset_rights_holder],dataset_rights_statement: params[:resource][:dataset_rights_statement], 
                        default_rights_holder: params[:resource][:default_rights_holder], default_rights_statement: params[:resource][:default_rights_statement],
                        default_license_string: params[:resource][:default_license_string], default_language_id: params[:resource][:default_language_id]}
    @resource = Resource.new(resource_params)
    @resource.flag =  params[:resource][:type].eql?("file")? true : false
    if @resource.valid?
      result = ResourceApi.add_resource?(resource_params, params[:content_partner_id])
      if !result.nil?
        flash[:notice] = I18n.t(:successfuly_created_resource)
        redirect_to controller: 'resources', action: 'show', id: result
      else
        flash.now[:notice] =I18n.t( :error_in_connection)
        render action: 'new'
      end
    else
      render action: 'new'
    end
  end
  
  def edit
    result= ResourceApi.get_resource(params[:content_partner_id], params[:id])
    mappings = {"_paused" => "is_paused", "_approved" => "is_approved" , "_trusted" => "is_trusted" , "_autopublished" => "is_autopublished" , "_forced" => "is_forced"}
    result.keys.each { |k| result[ mappings[k] ] = result.delete(k) if mappings[k] }
    @resource = Resource.new(result)
  end
  
  def update
    resource_params = { name: params[:resource][:name], origin_url: params[:resource][:origin_url],uploaded_url: params[:resource][:uploaded_url],
                        path: params[:resource][:path],type: params[:resource][:type],harvest_frequency: params[:resource][:harvest_frequency],
                        dataset_license: params[:resource][:dataset_license],
                        dataset_rights_holder: params[:resource][:dataset_rights_holder],dataset_rights_statement: params[:resource][:dataset_rights_statement], 
                        default_rights_holder: params[:resource][:default_rights_holder], default_rights_statement: params[:resource][:default_rights_statement],
                        default_license_string: params[:resource][:default_license_string], default_language_id: params[:resource][:default_language_id]}
    @resource = Resource.new(resource_params)
    @resource.flag = false
    if @resource.valid?
      result = ResourceApi.update_resource?(resource_params, params[:content_partner_id],params[:id])
      if !result.nil?
        flash[:notice] = I18n.t(:successfuly_updated_resource)
        redirect_to controller: 'resources', action: 'show', id: result
      else
        flash.now[:notice] = I18n.t(:error_in_connection)
        render action: 'edit'
      end
    else
      render action: 'edit'
    end
  end
  
  def show
    result_partner = ContentPartnerApi.get_content_partner(params[:content_partner_id])
    returned_content_partner = result_partner[0]
    content_partner_user = User.find(ContentPartnerUser.find_by_content_partner_id(returned_content_partner["id"].to_i).user_id)
    @content_partner = ContentPartner.new(id: returned_content_partner["id"].to_i, name: returned_content_partner["name"],
                                          logo: returned_content_partner["logo"],
                                          user: content_partner_user)
    result = ResourceApi.get_resource(params[:content_partner_id], params[:id])
    mappings = {"_paused" => "is_paused", "_approved" => "is_approved" , "_trusted" => "is_trusted" , "_autopublished" => "is_autopublished" , "_forced" => "is_forced"}
    result.keys.each { |k| result[ mappings[k] ] = result.delete(k) if mappings[k] }
    @resource = Resource.new(result)
  end
  
end
