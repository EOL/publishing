json.versions ["0.2"]
json.name "EOL Taxa"
json.identifierSpace reconciliation_id_space_url
json.schemaSpace "https://dwc.tdwg.org/list/"

json.defaultTypes @types do |type|
  json.id type.id
  json.name type.name
end

json.view do
  json.url "https://eol.org/{{id}}"
end

json.suggest do
  json.property do
    json.service_path "/properties/suggest"
    json.service_url api_reconciliation_url
  end
end

