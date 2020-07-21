# Crono job for building the sitemap (rake task)
class BuildSitemapJob < ApplicationJob
  def perform
    Rails.logger.warn("START BuildIdentifierMapJob")
    Rake::Task['sitemap:refresh:no_ping'].invoke
    Rails.logger.warn("END BuildIdentifierMapJob.")
  end
end
