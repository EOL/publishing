# Crono job for creating the provider_id.csv file which we then usually make availble here:
# http://eol.org/data/provider_ids.csv.gz
class BuildIdentifierMapJob < ApplicationJob
  def perform
    Rails.logger.warn("START BuildIdentifierMapJob")
    IdentifierMap.build
    Rails.logger.warn("END BuildIdentifierMapJob.")
  end
end
