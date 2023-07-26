class Medium
    class ManifestExporter
        class << self
            def export
                require 'csv'
                @collection_num = 1
                @collection = [[
                    'EOL content ID',
                    'EOL page ID',
                    'Medium Source URL',
                    'EOL Full-Size Copy URL',
                    'License Name',
                    'Copyright Owner']]
                puts "start #{Time.now}"
                STDOUT.flush
                # NOTE: this no longer restricts itself to visible or trusated media, but I think that's fine for the use-case.
                Medium.where('page_id IS NOT NULL').includes(:license).find_each do |item|
                    begin
                    @collection << [item.id, item.page_id, item.source_url, item.original_size_url, item.license&.name, item&.owner]
                    rescue => e
                    puts "FAILED on page item #{item.id} (#{item.resource.name})"
                    puts "ERROR: #{e.message}"
                    STDOUT.flush
                    end
                    flush_collection if @collection.size >= 100_000
                end
                puts "end #{Time.now}"
                flush_collection unless @collection.empty?
            end

            def flush_collection
                CSV.open(Rails.root.join('public', 'data', "media_manifest_#{@collection_num}.csv"), 'wb') do |csv|
                    @collection.each { |row| csv << row }
                end
                @collection = []
                puts "flushed ##{@collection_num} @ #{Time.now}"
                STDOUT.flush
                @collection_num += 1
            end
        end
    end
end