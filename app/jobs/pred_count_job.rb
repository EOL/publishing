class PredCountJob < ActiveJob::Base
  def perform
    # This is a dumb way of doing this, but I don't want to extract all of that to a class right now:
    `rails r scripts/top_pred_counts.rb`
  end
end
