# Crono job: warm nginx page caches for all native-hierarchy pages during off-hours.
# See SlowCacheWarmer for window / resume behavior.
class SlowWarmCacheJob < ApplicationJob
  def perform
    Rails.logger.warn('START SlowCacheWarmer.warm')
    SlowCacheWarmer.warm
    Rails.logger.warn('END SlowCacheWarmer.warm')
  end
end
