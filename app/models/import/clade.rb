class Import::Clade
  class << self
    # E.g.: Import::Clade.read("clade-7662.json")    # Carnivora
    #       Import::Clade.read("clade-7665.json")    # Procyonidae
    #       Import::Clade.read("clade-18666.json")   # Procyon
    def read(file)
      start_time = Time.now
      # Convenience. Less typing! Feel free to add your own.
      unless File.exist?(file)
        file = Rails.root.join("doc", file) if
          File.exist?(Rails.root.join("doc", file))
        file = "/Users/jrice/Downloads/#{file}" if
          File.exist?("/Users/jrice/Downloads/#{file}")
      end
      keys = [
        :articles, :attributions, :bibliographic_citations, :collections,
        :collected_pages, :collected_pages_media, :collection_associations,
        :content_sections, :curations, :languages, :licenses, :links,
        :locations, :media, :nodes, :occurrence_maps, :pages, :page_contents,
        :page_icons, :partners, :ranks, :references, :resources, :roles,
        :scientific_names, :sections, :taxonomic_statuses, :users, :vernaculars
      ]

      puts "Starting. Before:"
      count_classes(keys)

      contents = open(file) { |f| f.read } ; 1
      json = JSON.parse(contents) ; 1

      Sunspot.session = Sunspot::Rails::StubSessionProxy.new(Sunspot.session)
      begin
        create_active_records(keys, json)
        create_terms_and_traits(json["terms"], json["traits"])
        PageIcon.fix
      rescue => e
        puts "PROBLEM PARSING FILE?"
        debugger
        1
      ensure
        Sunspot.session = Sunspot.session.original_session
      end
      Reindexer.fix_common_names("Plantae", "plants")
      Reindexer.fix_common_names("Animalia", "animals")
      Reindexer.fix_all_counter_culture_counts
      puts "\nDone. Took #{((Time.now - start_time) / 1.minute).round} minutes."
      count_classes(keys)
      true
    end

    def create_active_records(keys, json)
      errors = []
      keys.each do |key|
        key = key.to_s
        klass = key.singularize.camelize.constantize
        puts "** #{key}: #{json[key].size}"
        # Some collected pages (and their media) are not included in our pages:
        # TODO: ideally, we wouldn't export these. :\
        skip_collected_pages = {}
        data = json[key]
        default_resource = Resource.native
        if klass == Article
          data.each do |instance|
            # TODO: we should apply this to MANY OTHER FIELDS. Sigh.
            sanitize_html(instance, "body")
          end
        elsif klass == BibliographicCitation
          data.each do |instance|
            # TODO: we should apply this to MANY OTHER FIELDS. Sigh.
            sanitize_html(instance, "body")
          end
        elsif klass == CollectedPage
          data.each do |instance|
            if instance["page_id"].nil? # Images collected for (our) missing pages
              skip_collected_pages[instance["collected_page_id"]] = true
            end
          end
          data.delete_if { |instance| instance["page_id"].nil? }
        elsif klass == CollectedPagesMedium
          data.delete_if { |instance| skip_collected_pages[instance["collected_page_id"]] }
        elsif klass == Node
          # We have to do these one at a time so that awesome_nested_set can do
          # it's thing:
          data.each do |instance|
            # Parent ID of 0 screws things up; root nodes need to be nil:
            instance["parent_id"] = nil if instance["parent_id"] == 0
            instance["resource_id"] = default_resource.id if
              instance["resource_id"].nil?
            begin
              klass.create(instance)
            rescue ActiveRecord::RecordNotUnique
              errors << "#{klass.name} already exists: #{instance}"
            rescue ActiveRecord::RecordNotFound => e
              # Thrown by awesome_nested_set callbacks...
              debugger
              errors << "#{klass.name} with id #{instance["id"]} could not be "\
                "moved: #{e.message}"
            rescue => e
              debugger
            end
          end
        elsif klass == Page
          data.delete_if { |instance| instance["native_node_id"].blank? }
        elsif klass == Resource
          # TODO Default value (at DB layer) might be better, here:
          data.each { |instance| instance["is_browsable"] = false unless instance["is_browsable"] }
        elsif klass == Role
           data.each { |instance| instance["name"] = instance["name"].downcase.gsub(/\s+/, "_") }
        elsif klass == Section
          data.each { |instance| instance["name"] = instance["name"].downcase.gsub(/\s+/, "_") }
        elsif klass == User
          # We prefer the is_admin name, but in the DB, it's actually
          # "admin" (I think because of Devise)
          data.each do |instance|
            if admin = instance.delete("is_admin")
              instance["admin"] = admin
            end
          end
        end
        # Everything except Nodes: NOTE: when we move this algorithm over to
        # publishing, note that there is a option: { on_duplicate_key_update:
        # [:title] } ...and while we'll have to write the set of fields for each
        # class, that's doable and will be nice to have!
        klass.import(data, on_duplicate_key_ignore: true) unless klass == Node
      end
      # Now we need to add denomralized page icons, because that didn't happen
      # automatically:
      json["page_icons"].each do |icon|
        Page.find(icon["page_id"]).update_attribute(:medium_id, icon["medium_id"]) if
          Page.exists?(icon["page_id"])
      end
      puts "ERRORS:\n#{errors.join("\n")}" unless errors.empty?
    end

    # NOTE the extra gsub is required to fix some weird unclosed e.g. bold tags.
    def sanitize_html(instance, field)
      @ok_tags ||= %w(a p b br i em strong ul li ol sup sub hr img small strike
        table tbody tr td th thead var wbr dfn dl dd dt del blockquote bdo bdi
        audio abbr)
      include ActionView::Helpers::SanitizeHelper
      instance[field] = Nokogiri::HTML::fragment(
          ActionController::Base.helpers.
          sanitize(instance[field], :tags => @ok_tags)).
          to_xml.gsub(/<\w+\/>/, ""
        )
    end

    def count_classes(keys)
      keys.each do |key|
        key = key.to_s
        klass = key.singularize.camelize.constantize
        puts "** #{key}: #{klass.count}"
      end
      puts "Traits: #{TraitBank.count}"
    end

    # TODO: we should first query TB to get back a list of all resource_pk's
    # for all of the resources and put that in a hash, and skip the traits
    # that are already there. Would be much faster than our current system
    # of looking for the trait one and a time before creating them.
    def create_terms_and_traits(j_terms, traits)
      terms = {}
      pages = {}
      suppliers = {}
      j_terms.values.each do |term|
        terms[term["uri"]] = TraitBank.create_term(term.symbolize_keys)
      end
      valid_page_id = Page.first.id
      default_resource = Resource.native
      faked_resource_count = 0
      traits.each do |trait|
        page_id = trait.delete("page_id")
        trait[:page] = pages[page_id] || add_page(page_id, pages)
        trait[:object_page_id] = trait.delete("association")
        trait.delete(:object_page_id) if trait[:object_page_id] == 0
        res_id = trait.delete("resource_id")
        # You MUST have a resource ID...
        if res_id.nil?
          faked_resource_count += 1
          res_id = default_resource.id
        end
        trait[:supplier] = suppliers[res_id] || add_supplier(res_id, suppliers)
        pred = trait.delete("predicate")
        unit = trait.delete("units")
        val_uri = trait.delete("value_uri")
        val_num = trait.delete("value_num")
        trait[:measurement] = val_num if val_num
        trait[:predicate] = terms[pred] || add_term(pred)
        trait[:units] = terms[unit] || add_term(unit)
        trait[:object_term] = terms[val_uri] || add_term(val_uri)
        trait[:metadata] = trait.delete("metadata").map do |md|
          md_pred = md.delete("predicate")
          md_val = md.delete("value_uri")
          md_unit = md.delete("units")
          md[:predicate] = terms[md_pred] || add_term(md_pred)
          md[:object_term] = terms[md_val] || add_term(md_val)
          md[:units] = terms[md_unit] || add_term(md_unit)
          md[:literal] = md.delete("value_literal")
          # TODO: I would feel better if we did more to check the measurement;
          # if there are units, we should have a measurement!
          md[:measurement] = md.delete("value_num")
          # TODO: add those back as links...
          md.symbolize_keys
        end
        trait[:statistical_method] = trait.delete("statistical_methods") # ooops.
        trait[:literal] = trait.delete("value_literal")
        trait[:source] = trait.delete("source_url")
        # The rest of the keys are "just right" and will work as-is:
        begin
          TraitBank.create_trait(trait.symbolize_keys)
        rescue Excon::Error::Socket => e
          begin
            TraitBank.create_trait(trait.symbolize_keys)
          rescue
            puts "** ERROR: could not add trait:"
            puts "** ID: #{trait["resource_pk"]}"
            puts "** Page: #{trait[:page]["data"]["page_id"]}"
            puts "** Predicate: #{trait[:predicate]["data"]["uri"]}"
          end
        rescue => e
          require "byebug"
          puts "NEOGRAPHY ERROR?"
          debugger
          1
        end
      end
      if faked_resource_count > 0
        puts "** #{faked_resource_count} traits were missing their resource "\
          "ID. They were set to #{default_resource.id}."
      end
    end

    def add_page(page_id, pages)
      tb_page = TraitBank.create_page(page_id)
      tb_page = tb_page.first if tb_page.is_a?(Array)
      if Page.exists?(page_id)
        page = Page.find(page_id)
        parent_id = page.try(:native_node).try(:parent).try(:page_id)
        if parent_id
          parent = pages[page_id] || add_page(parent_id, pages)
          parent = parent.first if parent.is_a?(Array)
          if parent_id == page_id
            puts "** OOPS: we just tried to add #{parent_id} as a parent to itself!"
          else
            puts "Adding parent #{parent_id} to page #{page_id}..."
            TraitBank.add_parent_to_page(parent, tb_page)
          end
        end
      else
        puts "Trait attempts to use missing page: #{page_id}, ignoring links"
      end
      pages[page_id] = tb_page
      tb_page
    end

    def add_supplier(res_id, suppliers)
      resource = TraitBank.create_resource(res_id)
      resource = resource.first if resource.is_a?(Array)
      suppliers[res_id] = resource
      resource
    end

    def add_term(uri)
      return(nil) if uri.blank?
      begin
        TraitBank.create_term(
          uri: uri,
          is_hidden_from_overview: true,
          is_hidden_from_glossary: true,
          name: uri,
          section_ids: [],
          definition: "auto-created, was empty",
          comment: "",
          attribution: ""
        )
      rescue Neography::PropertyValueException => e
        puts "** WARNING: Failed to set property on term... #{e.message}"
        puts "** This seems to occur with some bad trait data (passing in hashes instead of strings)"
        debugger
        1
      end
    end
  end
end
