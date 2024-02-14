class IdentifierMap
  CSV_HEADERS = %w[node_id resource_pk resource_id page_id preferred_canonical_for_page]

  class << self
    def build
      builder = self.new
      builder.build
    end
  end

  def initialize(params = nil)
    require 'zlib'
    @file = Rails.public_path.join('data', 'provider_ids.csv')
    @browsable_resource_ids = Resource.classification.pluck(:id)
    @file = params[:file] if params.key?(:file)
    @browsable_resource_ids = params[:resource_ids] if params.key?(:resource_ids)
    @debug = params[:debug]
    @line_count = 0
    log("IdentifierMap initialized")
  end
  
  def build
    log("#build START")
    build_csv
    zipped = zip_file
    remove_csv
    zipped
    log("#build END")
  end

  def build_csv
    log("#build_csv START")
    CSV.open(@file, 'wb') do |csv|
      csv << CSV_HEADERS
      Node.includes(:identifiers, :scientific_names, page: { native_node: :scientific_names }).
        where(resource_id: @browsable_resource_ids).
        find_each do |node|
          cols = build_columns(node)
          next if cols.nil?
          csv << cols
      end
    end
  end
  
  def build_columns(node)
    if node.page.nil?
      log("WARNING: SKIPPING missing page for Node##{node.id} **this shouldn't happen**")
      return nil
    end
    log("#build_columns #{@line_count} for Node##{node.id}, Page##{node.page_id}") if (@line_count % 10_000).zero?
    @line_count += 1
    use_node =  node.page.native_node || node
    name = use_node.canonical_form&.gsub(/<\/?i>/, '')
    [node.id, node.resource_pk, node.resource_id, node.page.id, name]
  end

  def zip_file
    log("#zip_file START")
    zipped = "#{@file}.gz"
    Zlib::GzipWriter.open(zipped) do |gz|
      gz.mtime = File.mtime(@file)
      gz.orig_name = @file.to_s
      gz.write IO.binread(@file)
    end
    return zipped
  end
  
  def remove_csv
    log("#remove_csv START")
    File.unlink(@file) rescue nil
  end

  def log(what)
    return unless @debug
    puts "[#{Time.now.strftime('%F %T')} ID_MAP] #{what}"
  end
end