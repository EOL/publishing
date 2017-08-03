class Import::Collections
  class << self
    def slurp(file = "collections.json")
      start_time = Time.now
      unless File.exist?(file)
        file = Rails.root.join("doc", file) if
          File.exist?(Rails.root.join("doc", file))
        # Convenience. Less typing! Feel free to add your own.
        file = "/Users/jrice/Downloads/#{file}" if
          File.exist?("/Users/jrice/Downloads/#{file}")
      end
      keys = [
        :collections, :collected_pages, :collected_pages_media,
        :collection_associations ]
      contents = open(file) { |f| f.read } ; 1
      json = JSON.parse(contents) ; 1
      Searchkick.disable_callbacks
      begin
        create_active_records(keys, json)
      rescue => e
        puts "PROBLEM PARSING FILE?"
        debugger
        1
      ensure
        Searchkick.enable_callbacks
      end
      puts "\nDone. Took #{((Time.now - start_time) / 1.minute).round} minutes."
      count_classes(keys, true)
    end

    def create_active_records(keys, json)
      errors = []
      keys.each do |key|
        key = key.to_s # in JSON, they are strings.
        klass = key.singularize.camelize.constantize
        if json[key]
          puts "** #{key}: #{json[key].size}"
          data = json[key]
          klass.import(data, on_duplicate_key_ignore: true)
        else
          puts "** WARNING: no entries found for #{key}!"
          debugger
          1
        end
      end
    end

    # TODO: extract. This is copied in clade.rb.
    def count_classes(keys, skip_traits = false)
      keys.each do |key|
        key = key.to_s
        klass = key.singularize.camelize.constantize
        puts "** #{key}: #{klass.count}"
      end
      puts "Traits: #{TraitBank.count}" unless skip_traits
    end
  end
end
