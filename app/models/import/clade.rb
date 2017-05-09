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

      contents = open(file) { |f| f.read }
      json = JSON.parse(contents)

      Sunspot.session = Sunspot::Rails::StubSessionProxy.new(Sunspot.session)
      begin
        create_active_records(keys, json)
        create_terms_and_traits(json["terms"], json["traits"])
      rescue => e
        puts "PROBLEM PARSING FILE?"
        debugger
        1
      ensure
        Sunspot.session = Sunspot.session.original_session
      end
      puts "Complete."
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
        json[key].each do |instance|
          begin
            if klass == User
              # We prefer the is_admin name, but in the DB, it's actually
              # "admin" (I think because of Devise)
              admin = instance.delete("is_admin")
              instance["admin"] = admin
            elsif klass == Resource
              # TODO Default value (at DB layer) might be better, here:
              instance["is_browsable"] = false unless instance["is_browsable"]
            elsif klass == CollectedPage
              if instance["page_id"].nil? # Images collected for (our) missing pages
                skip_collected_pages[instance["collected_page_id"]] = true
                next
              end
            elsif klass == CollectedPagesMedium
              next if skip_collected_pages[instance["collected_page_id"]]
            elsif klass == Node
              instance["parent_id"] = nil if instance["parent_id"] == 0
            end
            klass.create(instance)
          rescue ActiveRecord::RecordNotUnique
            errors << "#{klass.name} already exists: #{instance}"
          rescue ActiveRecord::RecordNotFound => e # Thrown by awesome_nested_set callbacks...
            debugger
            errors << "#{klass.name} with id #{instance["id"]} could not be moved: #{e.message}"
          rescue => e
            debugger
          end
        end
      end
      puts "ERRORS:\n#{errors.join("\n")}" unless errors.empty?
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
    def create_terms_and_traits(terms, traits)
      terms = {}
      pages = {}
      suppliers = {}
      terms.values.each do |term|
        terms[term["uri"]] = TraitBank.create_term(term.symbolize_keys)
      end
      valid_page_id = Page.first.id
      default_resource = Resource.first
      traits.each do |trait|
        page_id = trait.delete("page_id")
        trait[:page] = pages[page_id] || add_page(page_id, pages)
        trait[:object_page_id] = trait.delete("association")
        # This happens. :( I'm not sure why, but we can't have it:
        trait[:object_page_id] = valid_page_id if trait[:object_page_id] == 0
        res_id = trait.delete("resource_id")
        # You MUST have a resource ID...
        if res_id.nil?
          puts "** Trait for #{page_id} (#{trait["predicate"]}) was missing a resource ID. Faked."
          res_id = default_resource.id
        end
        trait[:supplier] = suppliers[res_id] || add_supplier(res_id, suppliers)
        pred = trait.delete("predicate")
        unit = trait.delete("units")
        val_uri = trait.delete("value_uri")
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
        rescue => e
          puts "NEOGRAPHY ERROR?"
          debugger
          1
        end
      end
    end

    def add_page(page_id, pages)
      tb_page = TraitBank.create_page(page_id).first
      if Page.exists?(page_id)
        page = Page.find(page_id)
        parent_id = page.try(:native_node).try(:parent).try(:page_id)
        if parent_id
          parent = pages[page_id] || add_page(parent_id, pages)
          TraitBank.add_parent_to_page(parent, page)
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
    end
  end
end
