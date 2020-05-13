class WarmCsvDownloadsJob < ApplicationJob
  def perform
    CsvDownloadWarmer.warm
  end
end
