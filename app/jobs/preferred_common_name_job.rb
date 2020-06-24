# Crono job for expiring old downloads that didn't finish.
class PreferredCommonNameJob < ApplicationJob
  def perform
    Rails.logger.warn("START PreferredCommonNameJob")
    Vernacular.prefer_best_vernaculars
    Rails.logger.warn("END PreferredCommonNameJob.")
  end
end
