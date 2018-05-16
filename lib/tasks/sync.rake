desc 'Sync with the harvester.'
task sync: :environment do
  Publishing.sync
end
