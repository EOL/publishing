# t.boolean  "classification",                         default: false

json.resources @resources do |resource|
  json.extract! resource, *%i(id nodes_count name abbr description notes is_browsable has_duplicate_nodes dataset_rights_holder dataset_rights_statement repository_id)
  json.is_classification_resource resource.classification?
  # json.links resource.link_json
  if partner = resource.partner
    json.partner do |json|
      json.extract! partner, *%i(name homepage_url)
    end
  end
  if license = resource.dataset_license
    json.dataset_license do |json|
      json.extract! license, *%i(name source_url)
    end
  end
end
