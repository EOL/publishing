class Page::Serializer
  class << self
    def store_clade(page)
      serializer = new(page)
      serializer.store_clade
    end
  end

  def initialize(page)
    @page = page
    @pages_dir = Rails.root.join('public', 'data', 'pages')
    Dir.mkdir(pages_dir.to_s, 0755) unless Dir.exist?(pages_dir.to_s)
    @pages_dir = @pages_dir.join(@page.id)
    Dir.mkdir(pages_dir.to_s, 0755) unless Dir.exist?(pages_dir.to_s)
    @filenames = []
  end

  def filename_for(table)
    pages_dir.join("#{table}.csv")
  end

  # TODO: collections and users ... maybe? Nice for testing...
  # TODO: curations
  # TODO: Resource filter
  def store_clade
    structure = {
      pages: [
        :occurence_map,
        { nodes: [ :identifiers, :node_ancestors, :resource, :rank,
                   { scientific_names: [ :resource, :taxonomic_status ],
                     vernaculars: [ :language, :resource ],
                     references: :referents } ] },
        page_contents_FILTER_media: {
          [ :image_info, :license, :resource, :language, :bibliographic_citation, :location, :sytlesheet, :javascript,
            :attributions,
            { content_sections: :section, references: :referents } ],
        },
        page_contents_FILTER_articles: {
          [ :license, :resource, :language, :bibliographic_citation, :location, :sytlesheet, :javascript, :attributions,
            { content_sections: :section, references: :referents } ],
        }
      ]
    }

    node_ids = @page.native_node.descendants.pluck(:id)
    node_ids << @page.native_node_id unless node_ids.include?(@page.native_node_id)
    page_ids = Node.where(id: node_ids.pluck(:page_id)
    @tables = {}
    # grab as much as you can, looping in batches
      # For each of the classes,



    @filenames
  end
end
