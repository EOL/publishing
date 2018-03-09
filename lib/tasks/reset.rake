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

    desc 'rebuild the database, sync with harvester.'
    task sync: :empty do
      Publishing.sync
      Rails.cache.clear
    end
  end

  desc 'reset the database, using the schema instead of migrations. Sync with harvester.'
  task sync: :environment do
    Rake::Task['log:clear'].invoke
    Rake::Task['db:reset'].invoke
    Rake::Task['searchkick:reindex:all'].invoke
    Publishing.sync
    Rails.cache.clear
  end
end
