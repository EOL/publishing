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
    resource_params = { name: params[:resource][:name], originUrl: params[:resource][:origin_url],uploadedUrl: params[:resource][:uploaded_url],
                        path: params[:resource][:path],type: params[:resource][:type],harvestFrequency: params[:resource][:harvest_frequency],
                        datasetLicense: params[:resource][:dataset_license],
                        datasetRightsHolder: params[:resource][:dataset_rights_holder],datasetRightsStatement: params[:resource][:dataset_rights_statement], 
                        defaultRightsHolder: params[:resource][:default_rights_holder], defaultRightsStatement: params[:resource][:default_rights_statement],
                        defaultLicenseString: params[:resource][:default_license_string], defaultLanguageId: params[:resource][:default_language_id]}
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
    mappings = {"paused" => "is_paused", "approved" => "is_approved" , "trusted" => "is_trusted" , "autopublished" => "is_autopublished" , "forced" => "is_forced"}
    result.keys.each { |k| result[ mappings[k] ] = result.delete(k) if mappings[k] }
    # @resource = Resource.new(name: result["name"],origin_url: result["original_url"],uploaded_url: result["uploaded_url"],
    # type: result["type"],path: result["path"],last_harvested_at: result["last_harvested_at"],harvest_frequency: result["harvest_frequency"],
    # day_of_month: result["day_of_month"],nodes_count: result["nodes_count"],position: result["position"],is_paused: result["_paused"],
    # is_approved: result["_approved"],is_trusted: result["_trusted"],is_autopublished: result["_autopublished"],is_forced: result["_forced"],
    # dataset_license: result["dataset_license"],dataset_rights_statement: result["dataset_rights_statement"],
    # dataset_rights_holder: result["dataset_rights_holder"],default_license_string: result["default_license_string"],
    # default_rights_statement: result["default_rights_statement"],default_rights_holder: result["default_rights_holder"],
    # default_language_id: result["default_language_id"],is_harvest_inprogress: result["is_harvest_inprogress"])
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
    returned_content_partner = ContentPartnerApi.get_content_partner_without_resources(params[:content_partner_id])
    # result_partner = ContentPartnerApi.get_content_partner(params[:content_partner_id])
     
    content_partner_user = User.find(ContentPartnerUser.find_by_content_partner_id(returned_content_partner["id"].to_i).user_id)
    @content_partner = ContentPartner.new(id: returned_content_partner["id"].to_i, name: returned_content_partner["name"],
                                          logo: returned_content_partner["logo"],
                                          user: content_partner_user)
    result = ResourceApi.get_resource(params[:content_partner_id], params[:id])
    @resource = Resource.new(name: result["name"],origin_url: result["originalUrl"],uploaded_url: result["uploadedUrl"],
    type: result["type"],path: result["path"],last_harvested_at: result["lastHarvestedAt"],harvest_frequency: result["harvestFrequency"],
    day_of_month: result["dayOfMonth"],nodes_count: result["nodesCount"],position: result["position"],is_paused: result["paused"],
    is_approved: result["approved"],is_trusted: result["trusted"],is_autopublished: result["autopublished"],is_forced: result["forced"],
    dataset_license: result["datasetLicense"],dataset_rights_statement: result["datasetRightsStatement"],
    dataset_rights_holder: result["datasetRightsHolder"],default_license_string: result["defaultLicenseString"],
    default_rights_statement: result["defaultRightsStatement"],default_rights_holder: result["defaultRightsHolder"],
    default_language_id: result["defaultLanguageId"])
    # mappings = {"_paused" => "is_paused", "_approved" => "is_approved" , "_trusted" => "is_trusted" , "_autopublished" => "is_autopublished" , "_forced" => "is_forced", "forced_internally"=> "forced_internally"}
    # result.keys.each { |k| result[ mappings[k] ] = result.delete(k) if mappings[k] }
    #@resource = Resource.new(result)
  end
  
end
