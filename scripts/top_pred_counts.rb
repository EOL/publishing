require "fileutils"

limit = 50
q = "MATCH (trait:Trait)-[:predicate]->(pred:Term)\n"\
    "WITH pred.uri AS uri, pred.name AS name, count(trait) as trait_count\n"\
    "WHERE name is not null\n"\
    "RETURN name, uri, trait_count\n"\
    "ORDER BY trait_count DESC\n"\
    "LIMIT #{limit}"\

puts "Running query"
raw_result = TraitBank.query(q)
puts "Query finished, processing results"

if raw_result && raw_result["data"]
  result = raw_result["data"].collect do |datum|
    {
      name: datum[0],
      uri: datum[1],
      count: datum[2]
    }
  end.to_json
else
  raise "No results returned"
end

file_path = Rails.root.join("data", "top_pred_counts.json")
backup_path = Rails.root.join("data", "top_pred_counts_prev.json")

puts "Checking for existing data file at #{file_path}"

if File.exist?(file_path)
  puts "Copying existing data file to #{backup_path}"
  FileUtils.copy_file(file_path, backup_path)
else
  puts "No existing file found"
end

puts "Writing data to #{file_path}"
File.open(file_path, "w") do |f|
  f.write(result)
end

puts "Done!"

