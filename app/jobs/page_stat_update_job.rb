class PageStatUpdateJob < ApplicationJob
  def perform
    Rails.logger.info("START PageStatUpdater.run")
    PageStatUpdater.run
    Rails.logger.info("END PageStatUpdater.run")
  end
end
