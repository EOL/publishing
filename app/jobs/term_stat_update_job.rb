class TermStatUpdateJob < ApplicationJob
  def perform
    Rails.logger.info("START TermStatUpdater.run")
    TermStatUpdater.run
    Rails.logger.info("END TermStatUpdater.run")
  end
end
