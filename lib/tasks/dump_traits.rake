# Purpose of this command: At the command line, generate a CSV file
# dump of the entire trait graphdb.  See the associated support module.
# This can also be used for partial dumps of particular clades.
# To obtain csv files via the web service, use the format=csv option
# for the appropriate web service.

namespace :dump_traits do

  desc 'Dump traits information from neo4j graphdb into a set of .csv files.'
  task dump: :environment do
    clade = ENV['ID'] ? ENV['ID'] : 2913056     # default = life
    limit = ENV['LIMIT'] ? ENV['LIMIT'] : 1000000
    TraitBank::TraitsDumper.dump_clade(clade,
                                       "sample-dumps/#{clade}-csv",
                                       limit)
  end

  desc 'Smoke test of traits dumper; finishes quickly.'
  task smoke: :environment do
    clade = ENV['ID'] ? ENV['ID'] : 7662     # Carnivora
    limit = ENV['LIMIT'] ? ENV['LIMIT'] : 100
    TraitBank::TraitsDumper.dump_clade(clade,
                                       "sample-dumps/#{clade}-smoke-csv",
                                       limit)
  end

end
