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
    log("Made pages data dir") if Dir.mkdir(@pages_dir, 0755) unless Dir.exist?(@pages_dir)
    @pages_dir = @pages_dir.join(@page.id.to_s)
    log("Made new page dir #{@page.id}") if Dir.mkdir(@pages_dir, 0755) unless Dir.exist?(@pages_dir)
    @filenames = []
    @limit = 100
  end

  def filename_for(table)
    pages_dir.join("#{table}.csv")
  end

  # TODO: collections and users ... maybe? Nice for testing...
  # TODO: curations
  # TODO: Resource filter
  def store_clade
    structure = [
      :occurrence_maps, {
        nodes: [ :identifiers, :node_ancestors, :resource, :rank,
                 { scientific_names: [ :resource, :taxonomic_status ],
                   vernaculars: [ :language, :resource ],
                   references_AS_parent: :referents } ],
        page_contents: [{
          media_AS_content: [
            # TODO: :sytlesheet, :javascript,
            :image_infos, :license, :resource, :language, :bibliographic_citation, :location, # TODO: :attributions,
              { content_sections: :section, references_AS_parent: :referents }
          ],
          articles_AS_content: [
            # TODO: :sytlesheet, :javascript,
            :license, :resource, :language, :bibliographic_citation, :location, # TODO: :attributions,
              { content_sections: :section, references_AS_parent: :referents }
          ]
        }]
      }
    ]

    node_ids = @page.native_node.descendants.pluck(:node_id)
    node_ids << @page.native_node_id
    page_ids = Node.where(id: node_ids).pluck(:page_id)
    @tables = { Page: page_ids }
    structure.each { |relationship| gather(:pages, page_ids, relationship) }
    # Write the tables as CSV to files...
    @filenames
  end

  def gather(source, source_ids, relationship)
    # YOU WERE HERE: You still need to handle "FILTER" in the names. ...At least for the first relationship.
    log("GATHER #{source}, (#{source_ids.size} ids), #{relationship.inspect}")
    if relationship.is_a?(Symbol) # e.g. :occurrence_map
      log(".. SYMBOL")
      gather_relationship_ids(source, source_ids, relationship)
    elsif relationship.is_a?(Array)
      log(".. ARRAY")
      relationship.each do |specific_relationship|
        gather(source, source_ids, specific_relationship)
      end
    elsif relationship.is_a?(Hash)
      log(".. HASH")
      relationship.each do |child, descendants|
        log(".. CHILD: #{child} ; DESC: #{descendants.inspect}")
        children_ids = gather_relationship_ids(source, source_ids, child)
        gather(child, children_ids, descendants)
      end
    else
      raise "I don't understand how to gather #{relationship} (#{relationship.class.name})"
    end
  end

  def gather_relationship_ids(source, source_ids, relationship)
    log("GATHER_REL_IDS #{source}, (#{source_ids.size} ids), #{relationship.inspect}")
    relationship_class = objectify(relationship)
    relationship_name = strip_name(relationship)
    source_class = objectify(source)
    @tables[relationship_class] ||= []
    new_ids =
      if relationship_name == relationship_name.singularize
        log("(singular)")
        source_class.where(id: source_ids).limit(@limit).pluck("#{relationship_name.singularize}_id")
      else
        log("(plural)")
        filter = { "#{source_class.name.underscore.singularize}_id" => source_ids }
        parent_field = nil
        if relationship.to_s =~ /_AS_(\w+)$/
          log(".. SPECIAL 'AS' HANDLER")
          parent_field = $1
          filter = { "#{parent_field}_id" => source_ids }
        end
        # AUGH! This is hard. Content is polymorphic, so handle the case specially:
        if parent_field == 'content'
          log(".. SPECIAL CONTENT HANDLER")
          source_class.where(id: source_ids).limit(@limit).pluck("content_id")
        else
          log(".. NORMAL PLURAL")
          relationship_class.where(filter).limit(@limit).pluck(:id)
        end
      end
    new_ids.uniq!
    @tables[relationship_class] += new_ids
    log(".. FOUND #{new_ids.size} new IDs")
    new_ids
  end

  def objectify(original_name)
    name = strip_name(original_name)
    Object.const_get(name.singularize.classify)
  end

  def strip_name(name)
    name.to_s.sub(/_(FILTER|AS)_\w+$/, '')
  end

  def log(what)
    # TODO: better logging. For now:
    puts "** #{what}"
    Rails.logger.info("[#{Time.now.strftime('%H:%M:%S.%3N')}] SERIALIZER: #{what}")
  end
end
