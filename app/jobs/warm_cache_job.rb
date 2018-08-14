class WarmCacheJob < ActiveJob::Base
  def perform
    Rails.logger.warn("START CacheWarmer.warm")
    CacheWarmer.warm
    Rails.logger.warn("TraitBank::Terms.warm_caches")
    TraitBank::Terms.warm_caches
    Rails.logger.warn("END CacheWarmer.warm")
  end
end
