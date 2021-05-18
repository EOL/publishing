json.versions ["0.2"]
json.name "EOL Pages"
json.identifierSpace "<uri goes here>"
json.schemaSpace "<uri goes here>"

json.types @types do |type|
  json.name type.name
  json.description type.description
end

json.view "https://eol.org{{id}}"
