namespace :cache do
  desc 'Warm all of the caches. This can take quite a while. You should background the task.'
  task warm: :environment do
    CacheWarmer.warm
    TraitBank::Terms.warm_caches
  end
end
