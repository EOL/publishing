class Page::Serializer
  class << self
    def store_clade(node)
      serializer = new(node)
      serializer.store_clade
    end
  end

  def initialize(node)
    @node = node
    @nodes_dir = Rails.root.join('public', 'data', 'nodes')
    Dir.mkdir(nodes_dir.to_s, 0755) unless Dir.exist?(nodes_dir.to_s)
    @nodes_dir = @nodes_dir.join(@node.id)
    Dir.mkdir(nodes_dir.to_s, 0755) unless Dir.exist?(nodes_dir.to_s)
    @filenames = []
  end

  def filename_for(table)
    nodes_dir.join("#{table}.csv")
  end

  # TODO: collections and users ... maybe? Nice for testing...
  # TODO: curations
  def store_clade
    class_structure = {
      nodes: [ :identifiers, :node_ancestors, :page,
               { scientific_names: [ :resource, :taxonomic_status ],
                 vernaculars: [ :language, :resource ],
                 # Media does NOT include page_icons or pages or collected_pages, because we don't know the scope of
                 # pages to care about.
                 media: [ :image_info, :license, :resource, :language,
                          { content_sections: :section, references: :referents } ],
                 references: :referents } ]
    }
    # nodes, identifiers, ancestors, references (and referents), vernaculars, languages, scientific_names, media,
    # licenses, bibliographic_citations, locations, attributions, articles, maps, resources, ranks

    # NOT: pages, parent,
    node_ids = @node.descendants.pluck(:id)
    node_ids << @node.id unless node_ids.include?(@node.id)
    # grab as much as you can, looping in batches
      # For each of the classes,



    @filenames
  end
end
