class Import::Clade
  class << self
    # This is the OLD version, which, if you're reading this, is probably safe
    # to delete:
    def from_file(name)
      @resource_nodes = {}
      # Test with:
      # Import::Clade.from_file(Rails.root.join("doc", "store-2858300-clade.json"))
      file =  if Uri.is_uri?(name.to_s)
                open(name) { |f| f.read }
              else
                begin
                  File.read(name)
                rescue Errno::ENOENT
                  puts "NO SUCH FILE: #{name}"
                  exit(1)
                end
              end
      parse_clade(JSON.parse(file))
      # NOTE: You mmmmmmight want to delete everything before you call this, but
      # I'm skipping that now. Sometimes you won't want to, anyway...
    end

    def parse_clade(pages)
      pages.each do |page|
        Import::Page.parse_page(page)
      end
      puts "Finished: #{Page.count} pages, #{Node.count} nodes,"
      puts "#{Medium.count} media, #{Article.count} articles,"
      puts "#{Collection.count} collections."
    end

    # E.g.: Import::Clade.read("clade-7665.json")
    def read(file)
      # Convenience. Less typing! Feel free to add your own.
      unless File.exist?(file)
        file = Rails.root.join("doc", file) if
          File.exist?(Rails.root.join("doc", file))
        file = "/Users/jrice/Downloads/#{file}" if
          File.exist?("/Users/jrice/Downloads/#{file}")
      end
      also = [:terms]
      keys = [
        :articles, :attributions, :bibliographic_citations, :collections,
        :collected_pages, :collected_pages_media, :collection_associations,
        :content_sections, :curations, :languages, :licenses, :links,
        :locations, :media, :nodes, :occurrence_maps, :pages, :page_contents,
        :page_icons, :partners, :ranks, :references, :resources, :roles,
        :scientific_names, :sections, :taxonomic_statuses, :traits, :users,
        :vernaculars
      ]
      contents = open(file) { |f| f.read }
      json = JSON.parse(contents)
      errors = []
      Sunspot.session = Sunspot::Rails::StubSessionProxy.new(Sunspot.session)
      begin
        keys.each do |key|
          key = key.to_s
          klass = key.singularize.camelize.constantize
          puts "** #{key}: #{json[key].size}"
          # json[key].each do |instance|
          json[key][0..10].each do |instance|
            begin
              klass.create(instance)
            rescue ActiveRecord::RecordNotUnique
              errors << "#{klass.name} already exists: #{instance}"
            rescue ActiveRecord::RecordNotFound => e # Thrown by awesome_nested_set callbacks...
              errors << "#{klass.name} with id #{instance["id"]} could not be moved: #{e.message}"
            rescue => e
              debugger
            end
          end
          puts "ERRORS:\n#{errors.join("\n")}" unless errors.empty?
        end
      rescue => e
        puts "PROBLEM PARSING FILE?"
        debugger
      ensure
        Sunspot.session = Sunspot.session.original_session
      end
      true
    end
  end
end
