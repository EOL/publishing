namespace :cache do
  desc 'Warm all of the caches. This can take quite a while. You should background the task.'
  task warm: :environment do
    puts "CacheWarmer.warm"
    CacheWarmer.warm
    puts "Done."
  end

  desc 'Slow-warm nginx caches for all native pages + tabs. Respects off-hours unless IGNORE_WINDOW=1.'
  task slow_warm: :environment do
    ignore = ENV['IGNORE_WINDOW'].present?
    puts "SlowCacheWarmer.warm(ignore_window: #{ignore})"
    SlowCacheWarmer.warm(ignore_window: ignore)
    puts "Done."
  end
end
