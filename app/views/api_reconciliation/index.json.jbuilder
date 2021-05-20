json.versions ["0.2"]
json.name "EOL Taxa"
json.identifierSpace reconciliation_id_space_url
json.schemaSpace "https://dwc.tdwg.org/list/"

json.defaultTypes @types do |type|
  json.id type.id
  json.name type.name
end

json.view "https://eol.org/{{id}}"
