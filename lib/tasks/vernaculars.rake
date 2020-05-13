namespace :vernaculars do
  desc 'Create a file (i.e: public/data/vernacular_names.csv) of ALL vernacular data.'
  task dump: :environment do
    puts "Starting."
    VernacularNamesDumper.create_names_dump
    puts "Done."
  end
end
