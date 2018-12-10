module LegacyPort
  class PortCollections
    def self.port(fname)
      porter = new(fname)
      porter.port
    end

    def initialize(fname)
      @data = File.readlines(Rails.root.join(fname))
      @collection_id_map = {}
      @associations = {}
      @collection = nil
      @owners = []
      @added_ids = []
    end

    def port
      @data.each do |line|
        port_line(line)
      end
      build_collection_associations
      puts "Added collections: #{@added_ids.join(', ')}"
    end

    def port_line(line)
      begin
        if build_collection(line)
          add_owners
          add_items
        end
      rescue => e
        puts "Failed to build collection: #{line}"
        puts "ERROR: #{e.message}"
      end
    end

    def build_collection(line)
      c_hash = JSON.parse(line)
      @items = c_hash.delete('coll_items')
      if c_hash['name'] =~ /s Watch List$/
        puts "SKIPPING WATCH LIST: #{c_hash['name']}"
        return(nil)
      end
      c_hash['created_at'] = c_hash.delete('created')
      c_hash['updated_at'] = c_hash.delete('modified')
      c_hash['description'] = c_hash.delete('desc')
      old_id = c_hash['id'].to_i
      c_hash['v2_id'] = old_id
      c_hash.delete('logo_url') # Sorry, we can't handle these right now.
      @owners = c_hash.delete('coll_editors').split(';')
      if Collection.exists?(id: old_id)
        c_hash.delete('id')
      end
      begin
        @collection = Collection.create(c_hash)
        @added_ids << @collection.id
        puts "Collection #{old_id} id exists; changing ID to #{@collection.id}" unless @collection.id == old_id
        @collection_id_map[old_id] = @collection.id
      rescue => e
        raise e
      end
      @collection.id
    end

    def add_owners
      V2User.where(id: @owners).includes(:user).each do |v2_user|
        @collection.users << v2_user.user
        @owners.delete(v2_user.id.to_s)
      end
      @owners.each do |id|
        puts "Collection #{@collection.id} missing owner #{id}, skipping..."
      end
    end

    def add_items
      @items.each_with_index do |item_hash, position|
        add_item(item_hash, position)
      end
    end

    def add_item(item_hash, position)
      if item_hash['type'] == 'Collection'
        add_collected_collection(item_hash, position)
      elsif item_hash['type'] == 'TaxonConcept'
        add_collected_page(item_hash, position)
      else
        puts "!! Unhandled type #{item_hash['type']} for collection #{@collection.id}."
      end
    end

    def add_collected_collection(item_hash, position)
      @associations[@collection.id] ||= []
      item_hash['position'] = position
      @associations[@collection.id] << item_hash
    end

    def add_collected_page(item_hash, position)
      if Page.exists?(id: item_hash['object_id'])
        annotation = build_annotation(item_hash)
        begin
          CollectedPage.create(collection_id: @collection.id, page_id: item_hash['object_id'], position: position,
            annotation: annotation)
        rescue => e
          puts "Error collecting page #{item_hash['object_id']} for collection #{@collection.id}, skipped."
        end
      else
        puts "Missing page #{item_hash['object_id']} for collection #{@collection.id}, skipped."
      end
    end

    def build_collection_associations
      @associations.each do |collection_id, assocs|
        assocs.each do |assoc|
          associated_id = @collection_id_map[assoc['object_id']]
          if associated_id.nil?
            puts "Couldn't find associated collection #{assoc['object_id']}, skipping..."
          else
            annotation = build_annotation(assoc)
            begin
              CollectionAssociation.create(collection_id: collection_id, associated_id: associated_id,
                position: assoc['position'], annotation: annotation)
            rescue => e
              puts "Failed to create collection association #{collection_id}->#{associated_id}: #{e.message}"
            end
          end
        end
      end
    end

    def build_annotation(hash)
      # NOTE: ignoring hash['references'] for now because those are rare and only semi-delimited lists of integers... I
      # assume pointing to references in V2.
      elements = [hash['sort_field'], hash['name'], hash['annotation']].compact
      elements.delete_if { |e| e == "NULL"}
      elements.delete_if { |e| e =~ /left a comment on/}
      elements.join('. ').gsub(/\s+/, ' ')
    end
  end
end
