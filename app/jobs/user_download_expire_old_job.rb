# Crono job for expiring old downloads that didn't finish.
class UserDownloadExpireOldJob < ApplicationJob
  def perform
    Rails.logger.warn("START UserDownloadExpireOldJob")
    UserDownload.expire_old
    Rails.logger.warn("END UserDownloadExpireOldJob.")
  end
end
