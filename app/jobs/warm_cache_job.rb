class WarmCacheJob < ApplicationJob
  def perform
    Rails.logger.warn("START CacheWarmer.warm")
    CacheWarmer.warm
    Rails.logger.warn("TraitBank::Term.warm_caches")
    TraitBank::Term.warm_caches
    Rails.logger.warn("END CacheWarmer.warm")
  end
end
