def main_method  
  # json_content = get_latest_updates_from_hbase
   # nodes_file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'nodes4.json')
   # json_content = File.read(nodes_file_path)
   # unless json_content == false
     # nodes = JSON.parse(json_content)
     add_neo4j
    # nodes.each do |node|
      # res = Node.where(global_node_id: node["generatedNodeId"])
      # if res.count > 0
        # current_node = res.first
      # else
        # params = { resource_id: node["resourceId"],
                   # scientific_name: node["taxon"]["scientificName"], canonical_form: node["taxon"]["canonicalName"],
                   # rank: node["taxon"]["taxonRank"], global_node_id: node["generatedNodeId"],taxon_id: node["taxonId"] }
        # created_node = create_node(params)
#         
        # unless node["taxon"]["pageEolId"].nil? 
          # page_id = create_page({ resource_id: node["resourceId"], node_id: created_node.id, id: node["taxon"]["pageEolId"] }) # iucn status, medium_id
          # create_scientific_name({ node_id: created_node.id, page_id: page_id, canonical_form: node["taxon"]["canonicalName"],
                                 # node_resource_pk: node["taxon_id"], scientific_name: node["taxon"]["scientificName"],resource_id: node["resourceId"] })      
          # unless node["vernaculars"].nil?
            # create_vernaculars({vernaculars: node["vernaculars"], node_id: created_node.id, page_id: page_id, resource_id: node["resourceId"] })
          # end
#           
          # unless node["media"].nil?
            # create_media({media: node["media"],resource_id: node["resourceId"],page_id: page_id, references: node["references"]})
          # end
#           
          # # unless node["nodeData"]["ancestors"].nil?
            # # build_hierarchy({vernaculars: node["nodeData"]["ancestors"], node_id: created_node.id })
          # # end
#            
        # end      
      # end    
    # end
  # end    
end

def get_latest_updates_from_hbase
  hbase_uri = "#{HBASE_ADDRESS}#{HBASE_GET_LATEST_UPDATES_ACTION}"
  last_harvested_time = "1510150973451"
  begin    
    request =RestClient::Request.new(
        :method => :get,
        :timeout => -1,
        :url => "#{hbase_uri}/#{last_harvested_time}"
      )
      response = request.execute
      response.body
  rescue => e
    debugger
    false
  end
end

def build_hierarchy(ancestors, node_id)
  
end


def create_vernaculars(params)
  params[:vernaculars].each do |vernacular|
    language_id= vernacular["language"].nil? ? create_language("eng") : create_language(vernacular["language"])
    create_vernacular({ string: vernacular["name"], node_id: params[:node_id], page_id: params[:page_id],
                        is_preferred_by_resource: vernacular["isPreferred"], language_id: language_id,
                        resource_id: params[:resource_id]  })
  end
end

def create_media(params)
    params[:media].each do |medium|
      language_id = medium["language"].nil? ? create_language("eng") : create_language(medium["language"])
      license_id = medium["license"].nil? ? create_license("test") : create_license(medium["license"])
      location_id = medium["locationCreated"].nil? ? nil : create_location(location: medium["locationCreated"],
                    spatial_location: medium["genericLocation"],latitude: medium["latitude"],longitude: medium["longitude"],
                    altitude: medium["altitude"], resource_id: params[:resource_id])
      #base_url need to have default value
      medium_id = create_medium({ format: medium["format"],description: medium["description"],owner: medium["owner"],
                     resource_id: params[:resource_id],guid: medium["guid"],resource_pk: medium["mediaId"],source_page_url: medium["furtherInformationURI"],
                     language_id: language_id, license_id: license_id,location_id: location_id, base_url: "#{STORAGE_LAYER_IP}#{medium["storageLayerPath"]}"})
      #need to check  value , position
      fill_page_contents({resource_id: params[:resource_id],page_id: params[:page_id],source_page_id: params[:page_id],content_type: "Medium", content_id: medium_id})
      
      unless medium["agents"].nil?
        create_agents({resource_id: params[:resource_id], agents: medium["agents"], content_id: medium_id, content_type: "Medium",content_resource_fk: medium["mediaId"]})
      end
      
      #to show literature and references tab need to fill pages_referents table which won't be filled by us 
      unless params[:references].nil?
        create_referents({references: params[:references],resource_id: params[:resource_id], reference_id: medium["referenceId"],parent_id: medium_id,parent_type: "Medium",page_id: params[:page_id]})
      end
      
    end
  
end

def create_agents(params)
  params[:agents].each do |agent|
    create_agent(resource_id: params[:resource_id],role: agent["role"],content_id: params[:content_id], 
                 content_type: params[:content_type], resource_pk: agent["agentId"],value: agent["fullName"],url: agent["homepage"],content_resource_fk:params[:content_resource_fk])
  end
  
end

def create_agent(params)
  # need role default name
  role_id = params[:role].nil? ? create_role("roletest") : create_role(params[:role]) 
  create_attribution({resource_id: params[:resource_id],content_id: params[:content_id] ,content_type: params[:content_type],
                      role_id: role_id,url: params[:url], resource_pk: params[:resource_pk], value: params[:value], content_resource_fk: params[:content_resource_fk]})
end

def create_referents(params)
  reference_ids=params[:reference_id].split(';')
  reference_ids.each do|reference_id|
    params[:references].each do |reference|
      if reference["referenceId"] == reference_id
        body = "#{reference["primaryTitle"]} #{reference["secondaryTitle"]} #{reference["pages"]} #{reference["pageStart"]} "+
              "#{reference["pageEnd"]} #{reference["volume"]} #{reference["editor"]} #{reference["publisher"]} "+
              "#{reference["authorsList"]} #{reference["editorsList"]} #{reference["dataCreated"]} #{reference["doi"]}"
        referent_id = create_referent(body: body ,resource_id: params[:resource_id])
        create_references({referent_id: referent_id,parent_id: params[:parent_id],parent_type: params[:parent_type], resource_id: params[:resource_id]})
      end
    end
  end
end

def create_referent(params)
    res = Referent.where(body: params[:body],resource_id: params[:resource_id])
    if res.count > 0
      res.first.id
    else
      referent = Referent.create(body: params[:body],resource_id: params[:resource_id])
      referent.id
    end
    
end 

def create_references(params)
  #check searching parameters
  res = Reference.where(parent_id: params[:parent_id],parent_type: params[:parent_type],referent_id: params[:referent_id])
  if res.count > 0
    res.first.id
  else
    # id attribute must be autoincrement need to be edited in schema
    reference = Reference.create(parent_id: params[:parent_id],referent_id: params[:referent_id] ,parent_type: params[:parent_type],resource_id: params[:resource_id], id: 1)
    reference.id
  end
   
end

  

def create_node(params)
  rank_id = params[:rank].nil? ? nil : create_rank(params[:rank])
  node = Node.create(
    resource_id: params[:resource_id],
    page_id: params[:page_id],
    rank_id: rank_id,
    scientific_name: params[:scientific_name],
    canonical_form: params[:canonical_form],
    resource_pk: params[:taxon_id],
    global_node_id: params[:global_node_id])                             
    node                          
end

def create_role(name)
  res=Role.where(name: name)
  if res.count > 0
    res.first.id
  else
    role = Role.create(name: name)
    role.id 
  end
end

def create_rank(name)
  res = Rank.where(name: name)
  if res.count > 0
    res.first.id
  else
    rank = Rank.create(name: name)
    Rank.fill_in_missing_treat_as
    rank.id
  end  
end

def create_language(code)
  res = Language.where(code: code)
  if res.count > 0
    res.first.id
  else
    language = Language.create(code: code, group: code)
    language.id
  end
end

def create_license(source_url)
  res = License.where(source_url: source_url)
  if res.count > 0
    res.first.id
  else
    #in the name attribute , put the word "license" . to be able to edit it
    license = License.create(source_url: source_url, name: "license") 
    license.id
  end
end

def create_location(params)
  #need to add resource_id in seach??????
  res = Location.where(location: params[:location] ,longitude: params[:longitude],latitude: params[:latitude],
                       altitude: params[:altitude],spatial_location: params[:spatial_location])
  if res.count > 0
    res.first.id
  else
    location_id = Location.create(location: params[:location] ,longitude: params[:longitude],latitude: params[:latitude],
                                  altitude: params[:altitude],spatial_location: params[:spatial_location],resource_id: params[:resource_id])
    location_id
  end
end

def create_page(params)
  unless params[:id].nil?
    res = Page.where(id: params[:id])
    if res.count > 0
      res.first.id
    else
      # if params[:resource_id] == DYNAMIC_HIERARCHY_RESOURCE_ID
        page = Page.create(id: params[:id], native_node_id: params[:node_id], iucn_status: params[:iucn_status])
        page.id
      # end
    end
    else
      nil    
  end
end

def create_attribution(params)
  # search in attributions not final parameters
  res= Attribution.where(content_id: params[:content_id],content_type: params [:content_type],value: params[:value])
  if res.first
    res.first.id
  else
    attribution=Attribution.create(content_id: params[:content_id],content_type: params[:content_type],role_id: params[:role_id],
                                   value: params[:value], url: params[:url], resource_id: params[:resource_id], resource_pk: params[:resource_pk], 
                                   content_resource_fk: params[:content_resource_fk])
    attribution.id
  end
end

def create_vernacular(params)
  res = Vernacular.where(string: params[:string], node_id: params[:node_id])
  if res.count > 0
    res.first.id
  else
    vernacular_attributes = { string: params[:string] , language_id: params[:language_id] , node_id: params[:node_id], 
                              page_id: params[:page_id], resource_id: params[:resource_id] }
    unless params[:is_preferred_by_resource].nil?
      vernacular_attributes[:is_preferred_by_resource] = params[:is_preferred_by_resource]
    end
    
    vernacular = Vernacular.create(vernacular_attributes)
    vernacular.id
  end
  
end

def create_medium(params)
  res = Medium.where(guid: params[:guid])
  if res.count > 0
    res.first.id
  else
    medium= Medium.create(params)
    medium.id
  end
end



def create_scientific_name(params)
  # node_resource_pk = taxon_id
  # for now, we set italicized by canonical form but we should use global names tool
  # to separate scientific name and authority an surrond canonical form part with <i> </i> tags
  
  res = ScientificName.where(node_id: params[:node_id], canonical_form: params[:canonical_form])
  if res.count > 0
    res.first.id
  else
    canonical_form = params[:canonical_form].nil? ? params[:scientific_name] : params[:canonical_form]
    scientific_name = ScientificName.create(node_id: params[:node_id], page_id: params[:page_id], resource_id: params[:resource_id],canonical_form: canonical_form,
                                            node_resource_pk: params[:node_resource_pk], italicized: canonical_form , taxonomic_status_id: 1)
    scientific_name.id
  end  
end

def fill_page_contents(params)
  #need to add resource_id in seach??????
    res = PageContent.where(content_type:params[:content_type],content_id: params[:content_id]  ,page_id: params[:page_id] )
    if res.count > 0
      res.first.id
    else
      page_contents = PageContent.create(resource_id: params[:resource_id], content_type:params[:content_type],content_id: params[:content_id],page_id: params[:page_id],source_page_id: params[:source_page_id])
      page_contents.id
    end
      
end

def add_neo4j
  tb_page = TraitBank.create_page(1)
  resource = TraitBank.create_resource(147)
  options = {supplier:{"data"=>{"resource_id"=>147}}, resource_pk:"123" , page: 1,
             predicate:{"name"=>"lengthp","uri"=>"test/lengthp",section_ids:[1,2,3],definition:"test predicate definition"},
             object_term:{"name"=>"lengtho","uri"=>"test/lengtho",section_ids:[1,2,3],definition:"test object_term definition"},
             units: {"name"=>"cm","uri"=>"http://purl.obolibrary.org/obo/UO_0000008",section_ids:[1,2,3],definition:"test units"},
             literal:"10",
             metadata:[{predicate:{"name"=>"md_lengthp","uri"=>"test/md_lengthp",section_ids:[1,2,3],definition:"test predicate definition"},
                       object_term:{"name"=>"md_lengtho","uri"=>"test/md_lengtho",section_ids:[1,2,3],definition:"test object_term definition"},
                       units: {"name"=>"cm","uri"=>"http://eol.org/schema/terms/squarekilometer",section_ids:[1,2,3],definition:"test units"},
                       literal:"15"}] }
  trait=TraitBank.create_trait(options)
end


namespace :harvester do
  desc "TODO"  
  task get_latest_updates: :environment do
    main_method
  end
end
  
  
  
