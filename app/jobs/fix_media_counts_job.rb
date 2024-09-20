# Sometimes when you publish a resource, the pages that have NEW media
# will not show their media tab link, even though you can go to the URL (just add /media to it). This will fix the
# underlying problem, but does not clear cache, which may also be required.
class FixMediaCountsJob < ApplicationJob
  def perform
    Rails.logger.warn("START FixMediaCountsJob")
    Page.fix_media_counts
    Rails.logger.warn("END FixMediaCountsJob.")
  end
end
