# Crono job for building the sitemap (rake task)
class BuildsitemapJob < ApplicationJob
  def perform
    Rails.logger.warn("START BuildIdentifierMapJob")
    Rake::Task['sitemap:refresh:no_ping'].invoke
    Rails.logger.warn("END BuildIdentifierMapJob. Output to #{zipped}")
  end
end
