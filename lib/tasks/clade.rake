namespace :clade do
  desc 'Store a clade indicated by the PAGE_ID environment variable.'
  task store: :environment do
    raise "You must specify a PAGE_ID" unless ENV['PAGE_ID']
    Serializer.store_clade_id(ENV['PAGE_ID'])
  end

  desc 'Read a clade indicated by the CLADE_FILE environment variable.'
  task read: :environment do
    raise "You must specify a CLADE_FILE" unless ENV['CLADE_FILE']
    Importer.read_clade(ENV['CLADE_FILE'])
  end
end
