class DescCountsJob < ApplicationJob
  def perform
    Rails.logger.warn("START DescCountsJob")
    Rake::Task['desc_counts:generate'].invoke
    Rails.logger.warn("END DescCountsJob.")
  end
end
