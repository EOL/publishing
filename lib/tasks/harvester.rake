def main_method  
  # json_content = get_latest_updates_from_hbase
   nodes_file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'nodes5.json')
   json_content = File.read(nodes_file_path)
   unless json_content == false
     nodes = JSON.parse(json_content)
     nodes.each do |node|
       check_deltastatus_node({delta_status: node["taxon"]["deltaStatus"],resource_id: node["resourceId"],page_id: node["taxon"]["pageEolId"],
                   scientific_name: node["taxon"]["scientificName"], canonical_form: node["taxon"]["canonicalName"],
                   rank: node["taxon"]["taxonRank"], global_node_id: node["generatedNodeId"],taxon_id: node["taxonId"]})
      # res = Node.where(global_node_id: node["generatedNodeId"])
      # if res.count > 0
        # current_node = res.first
      # else
        # params = { resource_id: node["resourceId"],
                   # scientific_name: node["taxon"]["scientificName"], canonical_form: node["taxon"]["canonicalName"],
                   # rank: node["taxon"]["taxonRank"], global_node_id: node["generatedNodeId"],taxon_id: node["taxonId"] }
        # created_node = create_node(params)
      # end
      unless node["taxon"]["pageEolId"].nil? ||  node["taxon"]["deltaStatus"]== "D"
        node_id = Node.where(global_node_id: node["generatedNodeId"]).first.id
        page_id = create_page({ resource_id: node["resourceId"], node_id: node_id, id: node["taxon"]["pageEolId"] }) # iucn status, medium_id
        
         # create_scientific_name({ node_id: node_id, page_id: page_id, canonical_form: node["taxon"]["canonicalName"],
                                 # node_resource_pk: node["taxonId"], scientific_name: node["taxon"]["scientificName"],resource_id: node["resourceId"] })      
        unless node["vernaculars"].nil?
          check_deltastatus_vernaculars({vernaculars: node["vernaculars"], node_id: node_id, page_id: page_id, resource_id: node["resourceId"] })
        end
          
        unless node["media"].nil?
          check_deltastatus_media({media: node["media"],resource_id: node["resourceId"],page_id: page_id, references: node["references"]})
        end
        
        #here delete and update refrences only as create is inside the media
        unless node["references"].nil?
            check_deltastatus_references(references: node["references"],resource_id: node["resourceId"])
        end
        # if node["resourceId"]==147
          # add_neo4j(page_id: page_id,resource_id: node["resourceId"],resource_pk: node["taxonId"],scientific_name: node["taxon"]["scientificName"],occurrences: node["occurrences"],
                    # associations: node["associations"],measurementOrFacts: node["measurementOrFacts"])
        # end
#            
      end          
     end
   end    
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

def check_deltastatus_node(params)

if params[:delta_status]=="I"
  node_id = create_node({resource_id: params[:resource_id],
                         scientific_name: params[:scientific_name], canonical_form: params[:canonical_form],
                         rank: params[:rank], global_node_id: params[:global_node_id],taxon_id: params[:taxon_id]})
  unless params[:page_id].nil?
   create_scientific_name({ node_id: node_id, page_id: params[:page_id], canonical_form: params[:canonical_form],
                           node_resource_pk: params[:taxon_id], scientific_name: params[:scientific_name],resource_id: params[:reference_id]})
  end
elsif params[:delta_status] == "U"
  node_id = update_node({resource_id: params[:resource_id],
                         scientific_name: params[:scientific_name], canonical_form: params[:canonical_form],
                         rank: params[:rank], global_node_id: params[:global_node_id],taxon_id: params[:taxon_id]})
  update_scientific_name({ node_id: node_id, page_id: params[:page_id], canonical_form: params[:canonical_form],
                           node_resource_pk: params[:taxon_id], scientific_name: params[:scientific_name],resource_id: params[:reference_id]})
elsif params [:delta_status] == "D"
  node_id = delete_node(global_node_id: params[:global_node_id])
  scientific_names= ScientificName.where(node_id: node_id)
  if scientific_names.count > 0
    scientific_names.destroy_all
  end
  vernaculars = Vernacular.where(node_id: node_id)
  if vernaculars.count >0 
    vernaculars.destroy_all
  end
  
end
      
end

def check_deltastatus_vernaculars(params)
  params[:vernaculars].each do |vernacular|
    if vernacular["deltaStatus"] == "I"
      language_id= vernacular["language"].nil? ? create_language("eng") : create_language(vernacular["language"])
      create_vernacular({ string: vernacular["name"], node_id: params[:node_id], page_id: params[:page_id],
                        is_preferred_by_resource: vernacular["isPreferred"], language_id: language_id,
                        resource_id: params[:resource_id]  })
    elsif vernacular["deltaStatus"] == "U"
      language_id= vernacular["language"].nil? ? create_language("eng") : create_language(vernacular["language"])
      update_vernacular({string: vernacular["name"], node_id: params[:node_id], page_id: params[:page_id],
                        is_preferred_by_resource: vernacular["isPreferred"], language_id: language_id,
                        resource_id: params[:resource_id]})
    elsif vernacular["deltaStatus"] == "D"
      delete_vernacular({string: vernacular["name"], node_id: params[:node_id]})
    end
                        
  end
end

def check_deltastatus_media(params)
    params[:media].each do |medium|
      if medium["deltaStatus"] == "I"
        language_id = medium["language"].nil? ? create_language("eng") : create_language(medium["language"])
        license_id = medium["license"].nil? ? create_license("test") : create_license(medium["license"])
        location_id = medium["locationCreated"].nil? ? nil : create_location(location: medium["locationCreated"],
                    spatial_location: medium["genericLocation"],latitude: medium["latitude"],longitude: medium["longitude"],
                    altitude: medium["altitude"], resource_id: params[:resource_id])
      #base_url need to have default value
        medium_id = create_medium({ format: medium["format"],description: medium["description"],owner: medium["owner"],
                     resource_id: params[:resource_id],guid: medium["guid"],resource_pk: medium["mediaId"],source_page_url: medium["furtherInformationURI"],
                     language_id: language_id, license_id: license_id,location_id: location_id, base_url: "#{STORAGE_LAYER_IP}#{medium["storageLayerPath"]}"})

        fill_page_contents({resource_id: params[:resource_id],page_id: params[:page_id],source_page_id: params[:page_id],content_type: "Medium", content_id: medium_id})
       # when create mediasearch for its references to create
       #to show literature and references tab need to fill pages_referents table which won't be filled by us 
       unless params[:references].nil?
         create_referents({references: params[:references],resource_id: params[:resource_id], reference_id: medium["referenceId"],
                           parent_id: medium_id,parent_type: "Medium",page_id: params[:page_id]})
       end
      elsif medium["deltaStatus"] == "U"
        language_id = medium["language"].nil? ? create_language("eng") : create_language(medium["language"])
        license_id = medium["license"].nil? ? create_license("test") : create_license(medium["license"])
        location_id = medium["locationCreated"].nil? ? nil : create_location(location: medium["locationCreated"],
                    spatial_location: medium["genericLocation"],latitude: medium["latitude"],longitude: medium["longitude"],
                    altitude: medium["altitude"], resource_id: params[:resource_id])
      #base_url need to have default value
        medium_id = update_medium({ format: medium["format"],description: medium["description"],owner: medium["owner"],
                     resource_id: params[:resource_id],guid: medium["guid"],resource_pk: medium["mediaId"],source_page_url: medium["furtherInformationURI"],
                     language_id: language_id, license_id: license_id,location_id: location_id, base_url: "#{STORAGE_LAYER_IP}#{medium["storageLayerPath"]}"})
      elsif medium["deltaStatus"] == "D"
       medium_id = delete_medium({guid: medium["guid"]})
       delete_attribution_media(content_id: medium_id,content_type: "Medium")
       
      elsif medium["deltaStatus"] == "N"
        medium = Medium.where(guid: medium["guid"])
        if medium.count >0
          medium_id = medium.first.id
        end
         
      end
      
      unless medium["agents"].nil?
        check_status_agents({resource_id: params[:resource_id], agents: medium["agents"], content_id: medium_id, content_type: "Medium",content_resource_fk: medium["mediaId"]})
      end
      

      
    end
  
end

def check_status_agents(params)
  params[:agents].each do |agent|
    if agent["deltaStatus"] == "I"
      create_agent(resource_id: params[:resource_id],role: agent["role"],content_id: params[:content_id], content_type: params[:content_type],
                   resource_pk: agent["agentId"],value: agent["fullName"],url: agent["homepage"],content_resource_fk:params[:content_resource_fk])
    elsif agent["deltaStatus"] == "U"
      update_agent(resource_id: params[:resource_id],role: agent["role"],content_id: params[:content_id], content_type: params[:content_type],
                   resource_pk: agent["agentId"],value: agent["fullName"],url: agent["homepage"],content_resource_fk:params[:content_resource_fk])
    elsif agent["deltaStatus"] == "D"
      delete_agent(content_id: params[:content_id], content_type: params[:content_type], value: agent["fullName"])
    end
  end
  
end

def create_agent(params)
  # need role default name
  role_id = params[:role].nil? ? create_role("roletest") : create_role(params[:role]) 
  create_attribution({resource_id: params[:resource_id],content_id: params[:content_id] ,content_type: params[:content_type],
                      role_id: role_id,url: params[:url], resource_pk: params[:resource_pk], value: params[:value], content_resource_fk: params[:content_resource_fk]})
end

def update_agent(params)
  # need role default name
  role_id = params[:role].nil? ? create_role("roletest") : create_role(params[:role]) 
  update_attribution({resource_id: params[:resource_id],content_id: params[:content_id] ,content_type: params[:content_type],
                      role_id: role_id,url: params[:url], resource_pk: params[:resource_pk], value: params[:value], content_resource_fk: params[:content_resource_fk]})
end

def delete_agent(params)
  delete_attribution_agent(params)
end

def create_referents(params)
  reference_ids=params[:reference_id].split(';')
  reference_ids.each do|reference_id|
    params[:references].each do |reference|
      if reference["deltaStatus"] == "I"
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

def check_deltastatus_references(params)
  params[:references].each do |reference|
    body = "#{reference["primaryTitle"]} #{reference["secondaryTitle"]} #{reference["pages"]} #{reference["pageStart"]} "+
                "#{reference["pageEnd"]} #{reference["volume"]} #{reference["editor"]} #{reference["publisher"]} "+
                "#{reference["authorsList"]} #{reference["editorsList"]} #{reference["dataCreated"]} #{reference["doi"]}"
    # by updating referents table fields fields in refernces table won't be updated
    if reference["deltaStatus"] == "U"
     refere_id = update_referents(body: body,resource_id: params[:resource_id])
    elsif reference["deltaStatus"] == "D"
      referent_id = delete_referents(body: body, resource_id: params[:resource_id] )
      unless referent_id.nil?
        delete_references(referent_id: referent_id)
      end
    end
  end
  
end

# how update body as body is field of unique key
def update_referents(params)
  # res = Referent.where(body: params[:body],resource_id: params[:resource_id])
    # if res.count > 0
      # res.first.update(body: params[:body])
    # end
end

def delete_referents(params)
  referents = Referent.where(body: params[:body],resource_id: params[:resource_id])
    if referents.count > 0
      referent_id = referents.first.id
      referents.first.destroy
    end
      referent_id
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

def delete_references(params)
  res = Reference.where(referent_id: params[:referent_id])
  if res.count > 0
    res.delete_all
  end
end

def create_node(params)
  res = Node.where(global_node_id: params[:global_node_id])
  if res.count > 0
    current_node = res.first.id
  else
    rank_id = params[:rank].nil? ? nil : create_rank(params[:rank])
    node = Node.create(resource_id: params[:resource_id],page_id: params[:page_id],rank_id: rank_id, scientific_name: params[:scientific_name],
                       canonical_form: params[:canonical_form], resource_pk: params[:taxon_id], global_node_id: params[:global_node_id])                             
    node.id     
  end                     
end

def update_node(params)
  rank_id = params[:rank].nil? ? nil : create_rank(params[:rank])
  res = Node.where(global_node_id: params[:global_node_id])
  if res.count > 0
    node = res.first
    node.update(resource_id: params[:resource_id],page_id: params[:page_id],rank_id: rank_id, scientific_name: params[:scientific_name],
                       canonical_form: params[:canonical_form], resource_pk: params[:taxon_id])
    node.id
    
  end
end

def delete_node(params)
  node = Node.where(global_node_id: params[:global_node_id])
  if node.count > 0
    node_id = node.first.id
    node.first.destroy
  end
  node_id
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

def update_attribution(params)
  attribution= Attribution.where(content_id: params[:content_id],content_type: params [:content_type],value: params[:value])
  if attribution.count > 0
    attribution = attribution.first
    attribution.update(role_id: params[:role_id], url: params[:url], resource_id: params[:resource_id], resource_pk: params[:resource_pk], 
                       content_resource_fk: params[:content_resource_fk])
  end
end
def delete_attribution_agent(params)
  res= Attribution.where(content_id: params[:content_id],content_type: params [:content_type],value: params[:value])
  if res.count > 0
    res.first.destroy
  end
end

def delete_attribution_media(params)
  res= Attribution.where(content_id: params[:content_id],content_type: params [:content_type])
  if res.count > 0
    res.destroy_all
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

def delete_vernacular(params)
  vernacular = Vernacular.where(string: params[:string], node_id: params[:node_id])
  if vernacular.count > 0
    vernacular.first.destroy
  end
end

def update_vernacular(params)
  vernacular_attributes = {  language_id: params[:language_id] , page_id: params[:page_id], resource_id: params[:resource_id] }
  unless params[:is_preferred_by_resource].nil?
    vernacular_attributes[:is_preferred_by_resource] = params[:is_preferred_by_resource]
  end
    
  vernacular = Vernacular.where(string: params[:string], node_id: params[:node_id])
  if vernacular.count > 0
    vernacular.first.update(vernacular_attributes)
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

def delete_medium(params)
  res = Medium.where(guid: params[:guid])
  if res.count > 0
    medium_id = res.first.id
    res.first.destroy
    
  end
end

def update_medium(params)
  medium_attributes = { format: params[:format],description: params[:description],owner: params[:owner],
                     resource_id: params[:resource_id],resource_pk: params[:resource_pk],source_page_url: params[:source_page_url],
                     language_id: params[:language_id], license_id: params[:license_id],location_id: params[:location_id], base_url: params[:base_url]}
  medium = Medium.where(guid: params[:guid])
  if medium.count > 0 
    medium = medium.first
    medium.update(medium_attributes)
    medium.id
  end
end


def create_scientific_name(params)
  #assumption each node has 1 scientific name
  # node_resource_pk = taxon_id
  # for now, we set italicized by canonical form but we should use global names tool
  # to separate scientific name and authority an surrond canonical form part with <i> </i> tags
  canonical_form = params[:canonical_form].nil? ? params[:scientific_name] : params[:canonical_form]
  res = ScientificName.where(node_id: params[:node_id])
  if res.count > 0
    res.first.canonical_form
  else
    scientific_name = ScientificName.create(node_id: params[:node_id], page_id: params[:page_id], resource_id: params[:resource_id],canonical_form: canonical_form,
                                            node_resource_pk: params[:node_resource_pk], italicized: canonical_form , taxonomic_status_id: 1)
    scientific_name.canonical_form
  end  
end

def update_scientific_name(params)
  canonical_form = params[:canonical_form].nil? ? params[:scientific_name] : params[:canonical_form]
  res = ScientificName.where(node_id: params[:node_id])
  if res.count > 0
    res.first.update(page_id: params[:page_id], resource_id: params[:resource_id],node_resource_pk: params[:node_resource_pk],canonical_form: canonical_form,
                     italicized: canonical_form , taxonomic_status_id: 1)
  else
    ScientificName.create(node_id: params[:node_id], page_id: params[:page_id], resource_id: params[:resource_id],canonical_form: canonical_form,
                                            node_resource_pk: params[:node_resource_pk], italicized: canonical_form , taxonomic_status_id: 1)
  end
end

def delete_scientific_name(params)
   res = ScientificName.where(node_id: params[:node_id])
   if res.count > 0
     res.first.destroy
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

def add_neo4j(params)
    # tb_page = TraitBank.create_page(1)
  # resource = TraitBank.create_resource(147)
  tb_page = TraitBank.create_page(params[:page_id])
  resource = TraitBank.create_resource(params[:resource_id])
  options = {supplier:{"data"=>{"resource_id"=>params[:resource_id]}},
             resource_pk:params[:resource_pk] , page:params[:page_id], eol_pk:" 124", scientific_name: params[:scientific_name],
             predicate:{"name"=>"event date","uri"=>"test/event",section_ids:[1,2,3],definition:"test predicate definition"},
             object_term:{"name"=>"5/2/15","uri"=>"test/date",section_ids:[1,2,3],definition:"test object_term definition"},
             units: {"name"=>"cm","uri"=>"http://purl.obolibrary.org/obo/UO_0000008",section_ids:[1,2,3],definition:"test units"},
             literal:"10",
             metadata:[{predicate:{"name"=>"md_event","uri"=>"test/md_event",section_ids:[1,2,3],definition:"test predicate definition"},
                        object_term:{"name"=>"md_length1","uri"=>"test/md_length1",section_ids:[1,2,3],definition:"test object_term definition"},
                        units: {"name"=>"cm","uri"=>"http://eol.org/schema/terms/squarekilometer",section_ids:[1,2,3],definition:"test units"},
                        literal:"15"}] } 
  

  options_new = {supplier:{"data"=>{"resource_id"=>params[:resource_id]}},
             resource_pk:"12345", page:params[:page_id], eol_pk: "123", scientific_name: params[:scientific_name],
             predicate:{"name"=>"geographic dist","uri"=>"test/geographic",section_ids:[1,2,3],definition:"test predicate definition"},
             object_term:{"name"=>"gazetteer","uri"=>"test/gazetter",section_ids:[1,2,3],definition:"test object_term definition"},
             units: {"name"=>"cm","uri"=>"http://purl.obolibrary.org/obo/UO_0000033",section_ids:[1,2,3],definition:"test units"},
             literal:"10",
             metadata:[{predicate:{"name"=>"md_geographic","uri"=>"test/md_geographic",section_ids:[1,2,3],definition:"test predicate definition"},
                        object_term:{"name"=>"md_length2","uri"=>"test/md_length2",section_ids:[1,2,3],definition:"test object_term definition"},
                        units: {"name"=>"cm","uri"=>"http://eol.org/schema/terms/squareMicrometer",section_ids:[1,2,3],definition:"test units"},
                        literal:"15"}] } 
   # options = {supplier:{"data"=>{"resource_id"=>147}}, resource_pk:"123" , page: 1,
              # predicate:{"name"=>"lengthp","uri"=>"test/lengthp",section_ids:[1,2,3],definition:"test predicate definition"},
              # object_term:{"name"=>"lengtho","uri"=>"test/lengtho",section_ids:[1,2,3],definition:"test object_term definition"},
              # units: {"name"=>"cm","uri"=>"http://purl.obolibrary.org/obo/UO_0000008",section_ids:[1,2,3],definition:"test units"},
              # literal:"10",
              # metadata:[{predicate:{"name"=>"md_lengthp","uri"=>"test/md_lengthp",section_ids:[1,2,3],definition:"test predicate definition"},
                       # object_term:{"name"=>"md_lengtho","uri"=>"test/md_lengtho",section_ids:[1,2,3],definition:"test object_term definition"},
                       # units: {"name"=>"cm","uri"=>"http://eol.org/schema/terms/squarekilometer",section_ids:[1,2,3],definition:"test units"},
                       # literal:"15"}] }                   
  trait=TraitBank.create_trait(options)
  trait=TraitBank.create_trait(options_new)
end


namespace :harvester do
  desc "TODO"  
  task get_latest_updates: :environment do
    main_method
  end
end


  
