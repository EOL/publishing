namespace :publish do
  task last: :environment do
    Publishing::Fast.by_resource(Resource.last)
  end
end

desc 'Publish a resource by ID or ABBR.'
task publish: :environment do
  resource = ENV['ID'] ? Resource.find(ENV['ID']) : Resource.find_by_abbr(ENV['ABBR'])
  Publishing::Fast.by_resource(resource)
end
