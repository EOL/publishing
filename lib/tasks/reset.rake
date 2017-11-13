namespace :reset do
  namespace :full do
    desc 'rebuild the database, re-running migrations. Your gun, your foot: use caution. No imports are performed.'
    task empty: :environment do
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed'].invoke
      Rake::Task['searchkick:reindex:all'].invoke
    end

    desc 'rebuild the database, re-running migrations. Import is performed (harvester must be running on port 3000).'
    task import: :empty do
      Import::Repository.start
    end
  end

  desc 'reset the database, using the schema instead of migrations. Import is performed (harvester must be running).'
  task import: :environment do
    Rake::Task['db:reset'].invoke
    Rake::Task['searchkick:reindex:all'].invoke
    Import::Repository.start
  end
end
