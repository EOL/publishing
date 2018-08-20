namespace :clade do
  desc 'Store a clade indicated by the PAGE_ID environment variable.'
  task store: :environment do
    raise "You must specify a PAGE_ID" unless ENV['PAGE_ID']
    Serializer.store_clade_id(ENV['PAGE_ID'])
  end

  desc 'Read a clade indicated by the CLADE_FILE environment variable.'
  task read: :environment do
    raise "You must specify a CLADE_FILE" unless ENV['CLADE_FILE']
    ENV['CLADE_FILE'] = Rails.root.join(ENV['CLADE_FILE']) unless File.exist?(ENV['CLADE_FILE'])
    raise "Sorry, I can't find your clade file at #{ENV['CLADE_FILE']}. Did you give the full path?" unless
      File.exist?(ENV['CLADE_FILE'])
    Importer.read_clade(ENV['CLADE_FILE'])
  end
end
