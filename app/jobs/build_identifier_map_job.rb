# Crono job for creating the provider_id.csv file which we then usually make availble both here:
# https://opendata.eol.org/dataset/identifier-map (this is manually copied over, AFAIK)
# and here:
# http://eol.org/data/provider_ids.csv.gz
class BuildIdentifierMapJob < ApplicationJob
  def perform
    Rails.logger.warn("START BuildIdentifierMapJob")
    file = Rails.public_path.join('data', 'provider_ids.csv')
    CSV.open(file, 'wb') do |csv|
      csv << %w[node_id resource_pk resource_id page_id preferred_canonical_for_page]
      browsable_resource_ids = Resource.classification.pluck(:id)
      Node.includes(:identifiers, :scientific_names, page: { native_node: :scientific_names }).
           where(resource_id: browsable_resource_ids).
           find_each do |node|
             next if node.page.nil? # Shouldn't happen, but let's be safe.
             use_node =  node.page.native_node || node
             name = use_node.canonical_form&.gsub(/<\/?i>/, '')
             csv << [node.id, node.resource_pk, node.resource_id, node.page.id, name]
           end
    end
    require 'zlib'
    zipped = "#{file}.gz"
    Zlib::GzipWriter.open(zipped) do |gz|
      gz.mtime = File.mtime(file)
      gz.orig_name = file.to_s
      gz.write IO.binread(file)
    end
    File.unlink(file) rescue nil
    Rails.logger.warn("END BuildIdentifierMapJob. Output to #{zipped}")
  end
end
