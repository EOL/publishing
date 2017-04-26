def fake_node(page)
  page_id = page.id
  node = Node.create(
    resource_id: 6,
    page_id: page_id,
    rank_id: nil,
    scientific_name: "Faked Node for page #{page_id}",
    canonical_form: "Faked Node for page #{page_id}",
    resource_pk: "#{page_id}-1")
  page.update_attribute(:native_node, node)
  node
end

def add_trait(page, node, page_node, resource_node, trait)
  pred = TraitBank.term(trait[:predicate][:uri])
  units = trait[:units] ? TraitBank.term(trait[:units][:uri]) : nil
  term = trait[:object_term] ? TraitBank.term(trait[:object_term][:uri]) : nil
  meta = []
  if trait[:metadata]
    trait[:metadata].each do |md|
      mpred = TraitBank.term(md[:predicate][:uri])
      munits = md[:units] ? TraitBank.term(md[:units][:uri]) : nil
      mterm = md[:object_term] ? TraitBank.term(md[:object_term][:uri]) : nil
      meta << { predicate: mpred, units: munits, measurement: md["measurement"],
        term: mterm, literal: md["literal"] }
    end
  end
  TraitBank.create_trait(page: page_node,
    supplier: resource_node,
    resource_pk: node.resource_pk,
    scientific_name: node.scientific_name,
    predicate: pred,
    source: trait["source"],
    measurement: trait["measurement"],
    statistical_method: trait["statistical_method"],
    lifestage: trait["lifestage"],
    sex: trait["sex"],
    units: units,
    object_term: term,
    literal: trait["literal"],
    object_page_id: trait[:object_page_id],
    metadata: meta
  )
end

n = 0
limit = 1000
multiplier = 5
resource_node = TraitBank.find_resource(6)
done = {}
time = false
while true
  res = TraitBank.connection.execute_query(
    "MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource) "\
    "RETURN page ORDER BY page.page_id SKIP #{n} LIMIT #{limit} ") ; 1
  last unless res["data"]
  res["data"].each do |result|
    # result = res["data"].first
    id = result.first["data"]["page_id"].to_i
    next if done.has_key?(id)
    traits = []
    Rails.logger.error "*" * 100
    Rails.logger.error "++ #{id}"
    Rails.logger.error Benchmark.measure { traits = TraitBank.by_page(id) }
    Rails.logger.error "++ Had #{traits.size} traits"
    multiplier.times do
      page = Page.create
      node = fake_node(page)
      page_node = TraitBank.create_page(page.id)
      traits.each do |trait|
        add_trait(page, node, page_node, resource_node, trait)
      end
    end
    done[id] = true
  end
  n += limit
end

def get_column_data(name, results, col)
  return nil unless col.has_key?(name)
  return nil unless results[col[name]].is_a?(Hash)
  results[col[name]]["data"]
end

traits = []
previous_id = nil
col = {}
col_array.each_with_index { |c, i| col[c] = i }

trait_res = results["data"].first
resource = get_column_data(:resource, trait_res, col)
resource_id = resource ? resource["resource_id"] : "MISSING"
trait = get_column_data(:trait, trait_res, col)
page = get_column_data(:page, trait_res, col)
predicate = get_column_data(:predicate, trait_res, col)
object_term = get_column_data(:object_term, trait_res, col)
units = get_column_data(:units, trait_res, col)
meta_data = get_column_data(:meta, trait_res, col)
