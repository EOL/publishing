json.versions ["0.2"]
json.name "EOL Taxa"
json.identifierSpace "<uri goes here>"
json.schemaSpace "<uri goes here>"

json.types @types do |type|
  json.id type.id
  json.name type.name
end

json.view "https://eol.org{{id}}"
