def main_method  
  json_content = get_latest_updates_from_hbase
  
  # nodes_file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'nodes2.json')
  # json_content = File.read(nodes_file_path)
  unless json_content == false
    nodes = JSON.parse(json_content)
    nodes.each do |node|
      res = Node.where(global_node_id: node["generatedNodeId"])
      if res.count > 0
        current_node = res.first
      else
        params = { resource_id: node["resourceId"],
                   scientific_name: node["taxon"]["scientificName"], canonical_form: node["taxon"]["canonicalName"],
                   rank: node["taxon"]["taxonRank"], global_node_id: node["generatedNodeId"] }
        created_node = create_node(params)
        
        unless node["taxon"]["pageEolId"].nil? 
          page_id = create_page({ resource_id: node["resourceId"], node_id: created_node.id, id: node["taxon"]["pageEolId"] }) # iucn status, medium_id
          create_scientific_name({ node_id: created_node.id, page_id: page_id, canonical_form: node["taxon"]["canonicalName"],
                                 node_resource_pk: node["taxon_id"], scientific_name: node["taxon"]["scientificName"] })      
          unless node["vernaculars"].nil?
            create_vernaculars({vernaculars: node["vernaculars"], node_id: created_node.id, page_id: page_id, resource_id: node["resourceId"] })
          end
          
          # unless node["nodeData"]["ancestors"].nil?
            # build_hierarchy({vernaculars: node["nodeData"]["ancestors"], node_id: created_node.id })
          # end
           
        end      
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


def create_node(params)
  rank_id = params[:rank].nil? ? nil : create_rank(params[:rank])
  
  node = Node.create(
    resource_id: params[:resource_id],
    page_id: params[:page_id],
    rank_id: rank_id,
    scientific_name: params[:scientific_name],
    canonical_form: params[:canonical_form],
    resource_pk: "#{params[:page_id]}-1",
    global_node_id: params[:global_node_id])                             
    node                          
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
    language = Language.create(code: code)
    language.id
  end
end

def create_license(source_url)
  
end

def create_location()
  
end

def create_page(params)
  unless params[:id].nil?
    res = Page.where(id: params[:id])
    if res.count > 0
      res.first.id
    else
      if params[:resource_id] == DYNAMIC_HIERARCHY_RESOURCE_ID
        page = Page.create(id: params[:id], native_node_id: params[:node_id], iucn_status: params[:iucn_status])
        page.id
      end
    end
    else
      nil    
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

def create_scientific_name(params)
  # node_resource_pk = taxon_id
  # for now, we set italicized by canonical form but we should use global names tool
  # to separate scientific name and authority an surrond canonical form part with <i> </i> tags
  
  res = ScientificName.where(node_id: params[:node_id], canonical_form: params[:canonical_form])
  if res.count > 0
    res.first.id
  else
    canonical_form = params[:canonical_form].nil? ? params[:scientific_name] : params[:canonical_form]
    scientific_name = ScientificName.create(node_id: params[:node_id], page_id: params[:page_id], canonical_form: canonical_form,
                                            node_resource_pk: params[:node_resource_pk], italicized: canonical_form , taxonomic_status_id: 1)
    scientific_name.id
  end  
end



namespace :harvester do
  desc "TODO"  
  task get_latest_updates: :environment do
    main_method
  end
end
  
  
  
