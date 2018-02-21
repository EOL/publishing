desc 'List resources!'
task resources: :environment do
  Resource.all.each do |resource|
    puts "#{resource.id}: (#{resource.abbr}) #{resource.name}"
  end
end
