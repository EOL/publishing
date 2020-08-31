class WarmCacheJob < ApplicationJob
  def perform
    Rails.logger.warn("START CacheWarmer.warm")
    CacheWarmer.warm
    Rails.logger.warn("TraitBank::Glossary.warm_caches")
    TraitBank::Glossary.warm_caches
    Rails.logger.warn("END CacheWarmer.warm")
  end
end
