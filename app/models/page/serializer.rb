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
    structure = [
      :occurrence_map,
      { nodes: [ :identifiers, :node_ancestors, :resource, :rank,
                 { scientific_names: [ :resource, :taxonomic_status ],
                   vernaculars: [ :language, :resource ],
                   references: :referents } ],
        page_contents_FILTER_media: [
          :image_info, :license, :resource, :language, :bibliographic_citation, :location, :sytlesheet, :javascript,
            :attributions,
          { content_sections: :section, references: :referents }
        ],
        page_contents_FILTER_articles: [
          :license, :resource, :language, :bibliographic_citation, :location, :sytlesheet, :javascript, :attributions,
          { content_sections: :section, references: :referents }
        ]
      }
    ]

    node_ids = @page.native_node.descendants.pluck(:id)
    node_ids << @page.native_node_id unless node_ids.include?(@page.native_node_id)
    page_ids = Node.where(id: node_ids.pluck(:page_id)
    @tables = { Page: page_ids }
    structure.each do |relationship|
      gather(:pages, page_ids, relationship)
    end
    @filenames
  end

  def gather(source, source_ids, relationship)
    source_class = Object.const_get(source.to_s.singularize.classify)
    if relationship.is_a?(Symbol) # e.g. :occurrence_map
      gather_relationship_ids(source_class, source_ids, relationship)
    elsif relationship.is_a?(Array)
      relationship.each do |specific_relationship|
        gather_relationship_ids(source_class, source_ids, specific_relationship)
      end
    elsif relationship.is_a?(Hash)
      relationship.each do |child, descendants|
        children_ids = gather_relationship_ids(source_class, source_ids, child)
        gather(child, children_ids, descendants)
      end
    else
      raise "I don't understand how to gather #{relationship} (#{relationship.class.name})"
    end
  end

  def gather_relationship_ids(source_class, source_ids, relationship)
    relationship_class = Object.const_get(relationship.to_s.singularize.classify)
    @tables[relationship_class] ||= []
    new_ids +=
      if relationship.to_s == relationship.to_s.singularize
        source_class.where(id: source_ids).pluck("#{relationship}_id")
      else
        relationship_class.where("#{relationship}_id": source_ids).pluck(:id)
      end
    @tables[relationship_class] += new_ids
    new_ids
  end
end
