namespace :publish do
  desc 'Publish the last resource in the database (highest ID). This is usually the newest, but use caution.'
  task last: :environment do
    Publishing::Fast.by_resource(Resource.last)
  end

  desc 'Close all open import logs, allowing content to be synced.'
  task clear: :environment do
    ImportLog.all_clear!
    puts "All clear."
  end
end

desc 'Publish a resource by ID or ABBR.'
task publish: :environment do
  resource = ENV['ID'] ? Resource.find(ENV['ID']) : Resource.find_by_abbr(ENV['ABBR'])
  Publishing::Fast.by_resource(resource)
end
