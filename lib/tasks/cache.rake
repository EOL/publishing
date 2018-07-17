namespace :cache do
  desc 'Warm all of the caches. This can take quite a while. You should background the task.'
  task warm: :environment do
    puts "CacheWarmer.warm"
    CacheWarmer.warm
    puts "TraitBank::Terms.warm_caches"
    TraitBank::Terms.warm_caches
    puts "Done."
  end
end
