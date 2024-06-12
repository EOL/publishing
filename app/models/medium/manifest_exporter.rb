class Medium
    class ManifestExporter
        class << self
            def export
                require 'csv'
                @collection_num = 1
                @types = {
                    'video' => [Medium.subcategories[:video]],
                    'media' => [Medium.subcategories[:image], Medium.subcategories[:map_image]],
                    'audio' => [Medium.subcategories[:sound]]
                }
                puts "start #{Time.now}"
                STDOUT.flush
                @types.keys.each do |type|
                    reset_collection
                    puts "handling #{type} manifest..."
                    remove_existing_files(type)
                    # NOTE: this no longer restricts itself to visible or trusated media, but I think that's fine for the use-case.
                    Medium.where('page_id IS NOT NULL').where(subcategory: @types[type]).includes(:license).find_each do |item|
                        begin
                            @collection << [item.id, item.page_id, item.source_url, item.original_size_url, item.license&.name, item&.owner]
                        rescue => e
                            puts "FAILED on page item #{item.id} (#{item.resource.name})"
                            puts "ERROR: #{e.message}"
                            STDOUT.flush
                        end
                        flush_collection(type) if @collection.size >= 100_000
                    end
                    puts "created files #{Time.now} ... now archiving..."
                    flush_collection(type) unless @collection.empty?
                    zipfile = zip_collections(type)
                end
                puts "updating timestamp on OpenData..."
                update_opendata_timestamp
                puts "end #{Time.now}"
                return zipfile
            end

            def reset_collection
                @collection = [[
                    'EOL content ID',
                    'EOL page ID',
                    'Medium Source URL',
                    'EOL Full-Size Copy URL',
                    'License Name',
                    'Copyright Owner']]
            end

            def remove_existing_files(type)
                glob = Dir.glob(Rails.public_path.join('data', "#{type}_manifest_*.csv"))
                return if glob.empty?
                puts "removing #{glob.size} files ..."
                glob.each { |file| File.delete(file) }
            end

            def flush_collection(type)
                file = Rails.public_path.join('data', "#{type}_manifest_#{@collection_num}.csv")
                CSV.open(file, 'wb') do |csv|
                    @collection.each { |row| csv << row }
                end
                @collection = []
                puts "flushed ##{@collection_num} @ #{Time.now} > #{file}"
                STDOUT.flush
                @collection_num += 1
            end

            def zip_collections(type)
                dir = Rails.public_path.join('data')
                zipfile = Rails.public_path.join('data', "#{type}_manifest.tgz")
                File.unlink(zipfile) if File.exist?(zipfile)
                `cd #{dir} && tar cvzf #{zipfile} #{type}_manifest_*.csv`
                return zipfile
            end

            def update_opendata_timestamp
                api_uri = 'https://editors.eol.org/eol_php_code/update_resources/connectors/ckan_api_access.php'
                ckan_resource_id = 'f80f2949-ea76-4c2f-93db-05c101a2465c'
                `curl #{api_uri} -d ckan_resource_id=#{ckan_resource_id} -d "file_type=EOL file"`
            end
        end
    end
end