# Crono job for reindexing ElasicSearch through Searchkick. NOTE: this takes about a DAY to run!
class ReindexSearchkickJob < ApplicationJob
  def perform
    Rails.logger.warn("START ReindexSearchkickJob")
    Page.reindex(async: {wait: true}, resume: true)
    Rails.logger.warn("END ReindexSearchkickJob.")
  end
end
