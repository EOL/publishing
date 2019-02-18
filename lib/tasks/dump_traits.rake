# See ../../doc/dump_traits.md

# Not tested since TraitsDumper refactoring

# Might be better if the shell variables were EOL_XX instead of just XX

namespace :dump_traits do

  desc 'Dump traits information from neo4j graphdb into a set of .csv files.'
  task dump: :environment do
    clade = ENV['ID']       # nil if not provided
    chunksize = ENV['CHUNK']
    csvdir = ENV['CSVDIR']
    dest = ENV['ZIP']
    TraitsDumper.dump_clade(clade, csvdir, chunksize,
                            Proc.new {|cql| TraitBank::query(cql)},
                            dest)
  end

  desc 'Smoke test of traits dumper; finishes quickly.'
  task smoke: :environment do
    clade = ENV['ID'] || '7674'     # Felidae
    chunksize = ENV['CHUNK'] || '1000'
    csvdir = ENV['CSVDIR']
    dest = ENV['ZIP']
    TraitsDumper.dump_clade(clade, csvdir, chunksize,
                            Proc.new {|cql| TraitBank::query(cql)},
                            dest)
  end

end
