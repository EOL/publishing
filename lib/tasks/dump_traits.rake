# See ../../doc/dump_traits.md

namespace :dump_traits do

  desc 'Dump traits information from neo4j graphdb into a set of .csv files.'
  task dump: :environment do
    clade = ENV['ID'] || '2913056'     # default = life
    limit = ENV['LIMIT'] || '100000000'
    prefix = "traitbank_#{DateTime.now.strftime("%Y%m%d")}"
    prefix = "#{prefix}_#{clade}" if ENV['ID']
    prefix = "#{prefix}_limit_#{limit}" if ENV['LIMIT']
    csvdir = ENV['CSVDIR'] || "/tmp/#{prefix}_csv_temp"
    # This is not very rubyesque
    if ENV['ZIP']
      dest = ENV['ZIP']
    else
      dest = TraitBank::DataDownload.path.join("#{prefix}.zip")
    end
    TraitBank::TraitsDumper.dump_clade(clade, dest, csvdir, limit)
  end

  desc 'Smoke test of traits dumper; finishes quickly.'
  task smoke: :environment do
    clade = ENV['ID'] || '7662'     # Carnivora
    limit = ENV['LIMIT'] || '100'
    prefix = "traitbank_#{DateTime.now.strftime("%Y%m%d")}_#{clade}_#{limit}"
    csvdir = ENV['CSVDIR'] || "/tmp/#{prefix}_csv_temp"
    dest = ENV['ZIP'] || "#{prefix}_smoke.zip"
    TraitBank::TraitsDumper.dump_clade(clade, dest, csvdir, limit)
  end

end
