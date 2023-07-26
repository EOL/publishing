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
                remove_existing_files
                subclasses = [Medium.subclasses[:image], Medium.subclasses[:map_image]]
                # NOTE: this no longer restricts itself to visible or trusated media, but I think that's fine for the use-case.
                Medium.where('page_id IS NOT NULL').where(subclass: subclasses).includes(:license).find_each do |item|
                    begin
                        @collection << [item.id, item.page_id, item.source_url, item.original_size_url, item.license&.name, item&.owner]
                    rescue => e
                        puts "FAILED on page item #{item.id} (#{item.resource.name})"
                        puts "ERROR: #{e.message}"
                        STDOUT.flush
                    end
                    flush_collection if @collection.size >= 100_000
                end
                puts "created files #{Time.now} ... now archiving..."
                flush_collection unless @collection.empty?
                zip_collections
                puts "end #{Time.now}"
            end

            def remove_existing_files
                glob = Dir.glob(Rails.public_path.join('data', 'media_manifest_*.csv'))
                return if glob.empty?
                puts "removing #{glob.size} files ..."
                glob.each { |file| File.delete(file) }
            end

            def flush_collection
                file = Rails.public_path.join('data', "media_manifest_#{@collection_num}.csv")
                CSV.open(file, 'wb') do |csv|
                    @collection.each { |row| csv << row }
                end
                @collection = []
                puts "flushed ##{@collection_num} @ #{Time.now} > #{file}"
                STDOUT.flush
                @collection_num += 1
            end

            def zip_collections
                zipfile = Rails.public_path.join('data', 'media_manifest.tgz')
                File.unlink(zipfile) if File.exist?(zipfile)
                `tar cvzf #{zipfile} #{Rails.public_path.join('data')}/media_manifest_*.csv`
            end
        end
    end
end