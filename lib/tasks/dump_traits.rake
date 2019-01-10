# See ../../doc/dump_traits.md

namespace :dump_traits do

  desc 'Dump traits information from neo4j graphdb into a set of .csv files.'
  task dump: :environment do
    clade = ENV['ID']       # nil if not provided
    limit = ENV['LIMIT']
    chunksize = ENV['CHUNK'] || limit
    prefix = "traitbank_#{DateTime.now.strftime("%Y%m")}"
    prefix = "#{prefix}_#{clade}" if clade
    prefix = "#{prefix}_chunked_#{chunksize}" if chunksize
    csvdir = ENV['CSVDIR'] || "/tmp/#{prefix}_csv_temp"
    # This is not very rubyesque
    if ENV['ZIP']
      dest = ENV['ZIP']
    else
      dest = TraitBank::DataDownload.path.join("#{prefix}.zip")
    end
    TraitBank::TraitsDumper.dump_clade(clade, dest, csvdir, chunksize,
                                       ENV['SERVER'],
                                       ENV['TOKEN'])
  end

  desc 'Smoke test of traits dumper; finishes quickly.'
  task smoke: :environment do
    clade = ENV['ID'] || '7662'     # Carnivora
    chunksize = ENV['CHUNK'] || ENV['LIMIT'] || '100'
    prefix = "traitbank_#{DateTime.now.strftime("%Y%m")}_#{clade}_#{chunksize}"
    csvdir = ENV['CSVDIR'] || "/tmp/#{prefix}_csv_temp"
    dest = ENV['ZIP'] || "#{prefix}_smoke.zip"
    TraitBank::TraitsDumper.dump_clade(clade, dest, csvdir, chunksize, nil, nil)
  end

end
