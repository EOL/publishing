class Import::Clade
  class << self
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
  end
end
