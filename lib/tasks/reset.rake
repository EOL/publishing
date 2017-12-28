namespace :reset do
  namespace :full do
    desc 'rebuild the database, re-running migrations. Your gun, your foot: use caution. No imports are performed.'
    task empty: :environment do
      Rake::Task['log:clear'].invoke
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed'].invoke
      Rake::Task['searchkick:reindex:all'].invoke
      Rails.cache.clear
    end

    desc 'rebuild the database, re-running migrations. Import is performed (harvester must be running on port 3000).'
    task import: :empty do
      Publishing.start
      Rails.cache.clear
    end
  end

  desc 'reset the database, using the schema instead of migrations. Import is performed (harvester must be running).'
  task import: :environment do
    Rake::Task['log:clear'].invoke
    Rake::Task['db:reset'].invoke
    Rake::Task['searchkick:reindex:all'].invoke
    Publishing.start
    Rails.cache.clear
  end
end
