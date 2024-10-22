# Crono job for creating the all_provider_id.csv file which we then make availble here:
# http://eol.org/data/all_provider_ids.csv.gz
class BuildAllIdentifierMapsJob < ApplicationJob
  def perform
    Rails.logger.warn("START BuildIdentifierMapJob")
    IdentifierMap.build_all
    Rails.logger.warn("END BuildIdentifierMapJob.")
  end
end
