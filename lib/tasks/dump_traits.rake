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
    unless dest
      prefix = "traitbank_#{DateTime.now.strftime("%Y%m%d")}"
      prefix = "#{prefix}_#{clade}" if clade
      dest = TraitBank::DataDownload.path.join("#{prefix}.zip")
    end
    TraitsDumper.dump_clade(clade, dest, csvdir, chunksize,
                            Proc.new {|cql| TraitBank::query(cql)})
  end

  desc 'Smoke test of traits dumper; finishes quickly.'
  task smoke: :environment do
    clade = ENV['ID'] || '7674'     # Felidae
    chunksize = ENV['CHUNK'] || '100'
    csvdir = ENV['CSVDIR']
    dest = ENV['ZIP']
    unless dest
      prefix = "traitbank_#{DateTime.now.strftime("%Y%m%d")}_#{clade}_#{chunksize}"
      dest = "#{prefix}_smoke.zip"
    end
    TraitsDumper.dump_clade(clade, dest, csvdir, chunksize,
                            TraitBank::query)
  end

end
