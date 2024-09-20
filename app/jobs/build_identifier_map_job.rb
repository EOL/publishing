# Crono job for creating the provider_id.csv file which we then usually make availble both here:
# https://opendata.eol.org/dataset/identifier-map (this should actually just be a symlink to...)
# and here:
# http://eol.org/data/provider_ids.csv.gz
class BuildIdentifierMapJob < ApplicationJob
  def perform
    Rails.logger.warn("START BuildIdentifierMapJob")
    IdentifierMap.build
    Rails.logger.warn("END BuildIdentifierMapJob.")
  end
end
