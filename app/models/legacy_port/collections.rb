module LegacyPort
  class Collections
    def self.port(fname, options = {})
      porter = new(fname, options)
      porter.port
    end

    def self.add_collected_collections(fname, options = {})
      porter = new(fname, options)
      porter.add_collected_collections
    end

    def initialize(fname, options = {})
      @data = File.readlines(Rails.root.join(fname))
      @limit = (options[:limit] || 2000).to_i
      @logger ||= Logger.new("#{Rails.root}/log/collections_port.log")
      @added_ids = []
      clear_collection
    end

    def clear_collection
      @collection = nil
      @items = []
      @owners = []
    end

    def port
      @data.each_with_index do |line, index|
        port_line(line)
        clear_collection
        GC.start if (index % 100).zero?
      end
      @logger.warn("Added collections: #{@added_ids.join(', ')}")
    end

    def add_collected_collections
      @data.each do |line|
        c_hash = JSON.parse(line)
        id = c_hash['id']
        @collection = find_collection(id)
        if @collection
          @items = c_hash.delete('coll_items')
          @items.each_with_index do |item_hash, position|
            add_collected_collection(item_hash, position) if item_hash['type'] == 'Collection'
          end
        else
          @logger.warn(".. Collection #{id} was not found, skipping...")
        end
      end
    end

    def find_collection(id)
      return nil unless Collection.exists?(v2_id: id)
      Collection.find_by_v2_id(id)
    end

    def port_line(line)
      begin
        if build_collection(line)
          add_owners
          add_items
        end
      rescue => e
        @logger.warn("!! Failed to build collection: #{line}")
        @logger.warn("** ERROR: #{e.message}")
      end
    end

    def build_collection(line)
      c_hash = JSON.parse(line)
      old_id = c_hash['id'].to_i
      if find_collection(old_id)
        @logger.warn(".. Collection #{old_id} (#{c_hash['name']}) already exists, skipping.")
        return nil
      end
      if c_hash['name'] =~ /s Watch List$/
        @logger.warn(".. Collection #{old_id} (#{c_hash['name']}) is a watch list, skipping.")
        return(nil)
      end
      @items = c_hash.delete('coll_items')
      if @items.size > @limit
        @logger.warn(".. Collection #{old_id} (#{c_hash['name']}) is too large (#{@items.size}/#{@limit}), skipping.")
        @logger.warn(".. Description: #{c_hash['desc']}")
        @logger.warn(".. Users: #{get_usernames(c_hash['coll_editors']).join(', ')}")
        return(nil)
      end
      c_hash['created_at'] = c_hash.delete('created')
      c_hash['updated_at'] = c_hash.delete('modified')
      c_hash['description'] = c_hash.delete('desc')
      c_hash['v2_id'] = old_id
      c_hash.delete('logo_url') # Sorry, we can't handle these right now.
      @owners = c_hash.delete('coll_editors').split(';')
      if Collection.exists?(id: old_id)
        c_hash.delete('id')
      end
      begin
        @collection = Collection.create(c_hash)
        @added_ids << @collection.id
        @logger.warn(".. Collection #{old_id} id exists; changing ID to #{@collection.id}") unless
          @collection.id == old_id
      rescue => e
        raise e
      end
      @collection.id
    end

    def get_usernames(list)
      V2User.where(id: list).includes(:user).compact.map { |v2u| u = v2u.user ; "#{u.username} (#{u.email})" }
    end

    def add_owners
      V2User.where(id: @owners).includes(:user).each do |v2_user|
        @collection.users << v2_user.user
        @owners.delete(v2_user.id.to_s)
      end
      @owners.each do |id|
        @logger.warn(".. Collection #{@collection.id} missing owner #{id}, skipping...")
      end
    end

    def add_items
      @items.each_with_index do |item_hash, position|
        add_item(item_hash, position)
      end
    end

    def add_item(item_hash, position)
      if item_hash['type'] == 'TaxonConcept'
        add_collected_page(item_hash, position)
      elsif item_hash['type'] == 'Collection'
        # Do nothing, but don't warn!
      else
        @logger.warn("!! Unhandled type #{item_hash['type']} for collection #{@collection.id}.")
      end
    end

    def add_collected_page(item_hash, position)
      if Page.exists?(id: item_hash['object_id'])
        annotation = build_annotation(item_hash)
        begin
          CollectedPage.create(collection_id: @collection.id, page_id: item_hash['object_id'], position: position,
            annotation: annotation)
        rescue => e
          @logger.warn("!! Error collecting page #{item_hash['object_id']} for collection #{@collection.id}, skipped.")
        end
      else
        @logger.warn(".. Missing page #{item_hash['object_id']} for collection #{@collection.id}, skipped.")
      end
    end

    def add_collected_collection(item_hash, position)
      associated_collection = find_collection(item_hash['object_id'])
      if associated_collection
        associated_id = associated_collection.id
        annotation = build_annotation(item_hash)
        begin
          CollectionAssociation.create(collection_id: @collection.id, associated_id: associated_id,
            position: position, annotation: annotation)
        rescue => e
          @logger.warn("!! Failed to create collection association #{@collection.id}->#{associated_id}: #{e.message}")
        end
      else
        @logger.warn(".. Missing target collection association (#{item_hash['object_id']}) for #{@collection.id}, skipping...")
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
