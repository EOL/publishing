class FirstEntityRelationshipDiagram < ActiveRecord::Migration[4.2]
  def change
    create_table :languages do |t|
      t.string :code, null: false, limit: 12, index: true, unique: true,
        comment: "ISO 639-3; e.g.: 'eng' ...Note that the NAME of the language will be handled by "\
          "translation, e.g.: I18n.t('languages.' + lang.code)"
      t.string :group, null: false, limit: 12, index: true,
        comment: "ISO 639-1; e.g. 'en', allowing several dialects to be grouped for display, "\
          "when mutually intelligible"
      t.boolean :can_browse_site, null: false, default: false,
        comment: "whether to include this language in the drop-down of langauges with which you "\
          "may browse the site"
    end

    create_table :licenses do |t|
      t.string :name, null: false, comment: "was: title; either for Globalize or I18n key"
      t.string :source_url
      t.string :icon_url
      t.boolean :can_be_chosen_by_partners, null: false, default: false

      t.timestamps null: false
    end

    create_table(:resources) do |t|
      t.integer :partner_id, null: false, index: true

      t.string :name, null: false, comment: "was: title"
      t.string :url,
        comment: "the URL to download the resource from; was: accesspoint_url"
      t.text :description
      t.text :notes
      t.integer :nodes_count
      t.boolean :is_browsable, null: false, default: false
      t.boolean :has_duplicate_nodes, null: false, default: false

      # NOTE: these were removed in a later migration:
      t.integer :default_language_id
      t.integer :default_license_id, comment: "was: license_id"
      t.string :default_rights_statement, limit: 300,
        comment: "was: rights_statement"
      t.text :default_rights_holder, comment: "was: rights_holder"

      t.string :node_source_url_template,
        comment: "used to build the so-called outlink url; %%ID%% is replaced with the entry resource_pk; was: outlink_uri"

      t.datetime :last_published_at
      t.integer :last_publish_seconds

      t.integer :dataset_license_id,
        comment: "applies to the set of data itself (not its individual members)"
      t.string :dataset_rights_holder,
        comment: "applies to the set of data itself (not its individual members)"
      t.string :dataset_rights_statement,
        comment: "applies to the set of data itself (not its individual members)"

      t.timestamps null: false
    end
    # add_attachment :resources, :icon

    create_table :partners do |t|
      t.string :name, null: false
      t.string :abbr, limit: 16, comment: "was: acronym"
      t.string :short_name, null: false, comment: "was: display_name"
      t.string :homepage_url, comment: "was: partner_url"
      t.text :description
      t.text :notes, comment: "was: project_notes"
      t.text :links_json, comment: "allows multiple URLs (other than homepage) to be displayed"

      t.timestamps null: false
    end
    # add_attachment :partners, :icon
    create_join_table :partners, :users

    create_table :nodes do |t|
      t.integer :resource_id, null: false, index: true
      t.integer :page_id, index: true, comment: "null means it hasn't been put on the site yet; should be temporary only"
      t.integer :rank_id,
        comment: "note that this is neither trustworthy nor 'scientific', but it's useful for matching and for the community"
      t.integer :parent_id, index: true, comment: "null means root node"

      t.string :scientific_name, comment: "denormalized, italics included"
      t.string :canonical_form, comment: "denormalized, italics included"
      t.string :resource_pk, index: true, null: false,
        comment: "note that if this is missing in the resource, we will set it to the scientific name; was: identifier"
      t.string :source_url,
        comment: "optional dc:source value, should be different from resource.node_source_url_template + resource_pk; "\
          "we currently have 318 partners that provide this"

      t.boolean :is_hidden, null: false, default: false
      t.boolean :in_unmapped_area, null: false, default: false

      t.integer :children_count, :null => false, :default => 0

      t.timestamps null: false
    end

    create_table :identifiers do |t|
      t.integer :resource_id, index: true, null: false
      t.integer :node_id, index: true
      t.string :node_resource_pk, index: true, null: false
      t.string :identifier
    end

    create_table :ranks do |t|
      t.string :name, null: false
      t.integer :treat_as, default: nil,
        comment: "enum: r_domain r_kingdom r_phylum r_class r_order r_family r_genus r_species; when null, rank is ignored"
    end

    create_table :node_ancestors do |t|
      t.integer :resource_id, null: false
      t.integer :node_id, index: true, comment: "the id of the descendant node"
      t.integer :ancestor_id, index: true, comment: "the id of the node which is an ancestor"
      t.string :node_resource_pk, index: true
      t.string :ancestor_resource_pk, index: true
    end

    # Since taxon_remarks are relatively rare (1.4M / 40M), we store them in a separate table entirely. No sense in
    # having a text field that is usually empty.
    create_table :taxon_remarks do |t|
      t.integer :node_id, index: true
      t.text :body,
        comment: "may contain original identification, taxon status, rank, name qualifier, author name, and more; "\
          "html-formatted; can be as long as 4K chrs or more; about 1 in 40 resources includes this information"
    end

    create_table :pages do |t|
      t.integer :native_node_id,
        comment: "denormalized node ID from Dynamic Working Hierarchy, which we use to get the preferred ancestors, "\
          "children, and names; null implies 'floating' taxon and should only have one node associated"
      t.integer :moved_to_page_id, comment: "moved/merged/split by curator"

      t.timestamps null: false
    end

    # NOTE: this does NOT capture ratings or exemplars, which we need to add, but I need time to think about that! NOTE:
    # we DO really need an id field on this table, because we curate these.
    create_table :page_contents do |t|
      t.integer :page_id, null: false, index: true, comment: "the content is shown on this page."
      t.integer :resource_id, null: false, comment: "denormalized."
      t.integer :source_page_id, null: false, index: true,
        comment: "which page the content was *propaged from* (can == page_id)."
      t.integer :position, comment: "the order in which to show the content on the page"
      t.references :content, polymorphic: true, index: true, null: false

      t.integer :association_added_by_user_id, comment: "no resource added this association, it was added manually"

      # Current curation status (see relationships for history):
      t.integer :trust, null: false, default: 1, comment: "enum: unreviewed, trusted, untrusted"
      t.boolean :is_incorrect, null: false, default: false, comment: "implies untrusted"
      t.boolean :is_misidentified, null: false, default: false, comment: "implies untrusted"
      t.boolean :is_hidden, null: false, default: false
      t.boolean :is_duplicate, null: false, default: false, comment: "implies hidden"
      t.boolean :is_low_quality, null: false, default: false, comment: "implies hidden"

      t.timestamps null: false
    end
    add_index(:page_contents, [:page_id, :content_type],
      name: "page_content_by_type_index")
    add_index(:page_contents, [:page_id, :content_type, :content_id],
      name: "effective_pk", unique: true)

    # NOTE: changed is_hidden to a trust integer in later migration
    create_table :vernaculars do |t|
      t.string :string, null: false,
        comment: "note this does NOT need to be unique"
      t.integer :language_id, null: false
      t.integer :node_id, null: false, index: true
      t.integer :page_id, null: false, index: true,
        comment: "denormalized from node; indexed to get all names on page"
      t.boolean :is_preferred, null: false, default: false,
        comment: "should only be one true per language per page_id"
      t.boolean :is_preferred_by_resource, null: false, default: false
      t.boolean :is_hidden, null: false, default: false

      t.timestamps null: false
    end
    add_index :vernaculars, [:page_id, :language_id],
      name: "preferred_names_index"

    create_table :scientific_names do |t|
      t.integer :node_id, null: false, index: true
      t.integer :page_id, null: false, index: true,
        comment: "denormalized from node; indexed to get all names for a page"

      t.string :italicized, null: false,
        comment: "finding/applying the italicized pieces out of the normalized form (includes <i> tags)"
      t.string :canonical_form, null: false,
        comment: "pulling out only the canonical form from the normalized form (includes <i> tags)"

      t.integer :taxonomic_status_id, null: false,
        comment: "This is effectively the 'type' of scientific name (or synonym)"
      t.boolean :is_preferred, null: false, default: true,
        comment: "denormalized from taxonomic_status (it saves having to join the other table)"

      t.timestamps null: false
    end

    # Taxonomic Statuses are meant to describe the type of scientific name (or
    # synonym). ...The additional fields indicate how "usable" that name is and
    # guide how we should display the name on the site.
    create_table :taxonomic_statuses do |t|
      t.string :name, null: false,
        comment: "the string provided by the resource to describe the name type; "\
          "see app/models/taxonomic_status.rb for examples"
      t.boolean :is_preferred, null: false, default: true
      t.boolean :is_problematic, null: false, default: false,
        comment: "when true, should be indicated as dubious on the site"
      t.boolean :is_alternative_preferred, null: false, default: false,
        comment: "While preffered is always... preferred, these are next in line."
      t.boolean :can_merge, null: false, default: true,
        comment: "whether the name is suitable for merges"
    end

    create_table :image_info do |t|
      t.integer :resource_id, null: false, comment: "denormalized"
      t.integer :medium_id, null: false, index: true, unique: true, comment: "not polymorphic--only needed for images"
      t.string :original_size, null: false, limit: 12, comment: "e.g.: 1600x1200"
      t.string :large_size, limit: 12, comment: "e.g.: 1024x768"
      t.string :medium_size, limit: 12, comment: "e.g.: 600x400"
      t.string :small_size, limit: 12, comment: "e.g.: 100x80"
      t.decimal :crop_x, precision: 5, scale: 2, comment: "left edge, as a percent"
      t.decimal :crop_y, precision: 5, scale: 2, comment: "top edge, as a percent"
      t.decimal :crop_w, precision: 5, scale: 2, comment: "width (and thus height), as a percent"

      t.timestamps null: false
    end

    # NOTE: the FK is in the content table, which helps us know if there IS a location for a given piece of content.
    create_table :locations do |t|
      t.integer :resource_id, null: false, comment: 'denormalized'
      t.string :location
      t.decimal :longitude, precision: 64, scale: 12
      t.decimal :latitude, precision: 64, scale: 12
      t.decimal :altitude, precision: 64, scale: 12
      t.text :spatial_location
    end

    create_table :javascripts do |t|
      t.integer :resource_id, null: false, comment: 'denormalized'
      t.string :filename, null: false
    end

    create_table :stylesheets do |t|
      t.integer :resource_id, null: false, comment: 'denormalized'
      t.string :filename, null: false
    end

    # NOTE: added subclasses of map and js_map
    # NOTE: provider became a resource (only)
    create_table :media do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.references :provider, polymorphic: true, index: true, null: false

      t.integer :subclass, null: false, default: 0, index: true,
        comment: "enum: image, video, sound"
      t.integer :format, null: false, default: 0,
        comment: "enum: jpg, youtube, flash, vimeo, mp3, ogg, wav"

      t.integer :license_id, null: false
      t.integer :language_id
      t.integer :location_id
      t.integer :stylesheet_id
      t.integer :javascript_id
      t.integer :bibliographic_citation_id

      t.text :owner, null: false,
        comment: "html; was rights_holder; current longest is 493; if missing, *must* be populated "\
          "with another attribution agent or the resource name: we MUST show an owner"

      t.string :name, comment: "was: title"
      t.string :source_url
      t.text :description, comment: "html; run through namelinks"
      t.string :base_url, null: false,
        comment: "for images, you will add size info to this; was: object_url"

      t.timestamps null: false
    end

    # NOTE: provider became a resource (only)
    create_table :articles do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.references :provider, polymorphic: true, index: true, null: false

      t.integer :license_id, null: false
      t.integer :language_id
      t.integer :location_id
      t.integer :stylesheet_id
      t.integer :javascript_id
      t.integer :bibliographic_citation_id

      t.text :owner, null: false,
        comment: "html; was rights_holder; current longest is 493; if missing, *must* be populated "\
          "with another attribution agent or the resource name: we MUST show an owner"

      t.string :name, comment: "was: title"
      t.string :source_url
      t.text :body, null: false,
        comment: "html; run through namelinks; was description_linked"

      t.timestamps null: false
    end

    # NOT: changed the base_url to just be an icon_url, later
    # NOTE: provider became a resource (only)
    create_table :links do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.references :provider, polymorphic: true, index: true, null: false

      t.integer :language_id

      t.string :name, comment: "was: title"
      t.string :source_url
      t.text :description, null: false,
        comment: "html; run through namelinks; was description_linked"
      t.string :base_url, null: false,
        comment: "icon; you will add size info to this; was: object_url"

      t.timestamps null: false
    end

    # NOTE: we removed this and just made it a subclass of image ... for now.
    create_table :maps do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.references :provider, polymorphic: true, index: true, null: false

      t.integer :license_id, null: false
      t.integer :language_id
      t.integer :stylesheet_id
      t.integer :javascript_id
      t.integer :bibliographic_citation_id

      t.text :owner, null: false,
        comment: "html; was rights_holder; current longest is 493; if missing, *must* be populated "\
          "with another attribution agent or the resource name: we MUST show an owner"

      t.string :name, comment: "was: title"
      t.string :source_url
      t.string :base_url, null: false,
        comment: "the image of the map; you will add size info to this; was: object_url"

      t.timestamps null: false
    end

    # There are currently 1,084,941 published data objects with a non-empty
    # citation, out of 7,785,934 objects. Of those, there is a lot of
    # duplication, so I'm making this its own table.
    #
    # If you want to cite this article on EOL, use this citation. It describes
    # "this content." Appears in the attribution information for the content.
    create_table :bibliographic_citations do |t|
      t.integer :resource_id, null: false, comment: 'denormalized'
      t.text :body, comment: "html; can be *quite* large (over 10K chrs)"

      t.timestamps null: false
    end

    # These are citations made by the partner, citing sources used to synthesize
    # that content. These show up below the content (only applies to articles);
    # this is effectively a "section" of the content; it's part of the object.
    create_table :references do |t|
      t.text :body, comment: "html; can be *quite* large (over 10K chrs)"

      t.timestamps null: false
    end

    # NOTE: we made this apply only to articles, later.
    create_table :content_references do |t|
      t.integer :reference_id, null: false, index: true
      t.references :content, polymorphic: true, index: true, null: false
    end

    create_table :roles do |t|
      t.string :name, null: false, comment: "passed to I18n.t"

      t.timestamps null: false
    end

    # NOTE: we merged this table with the join table; duplicates okay. NOTE: the
    # "Source Information" is MOSTLY attributions, but it's ALSO location and
    # license information and may contain other metadata. Thus, the name
    # "attributions," while not appearing on the site, is accurate.
    create_table :attributions do |t|
      t.integer :role_id, null: false, index: true
      t.text :value, null: false, comment: "html"

      t.timestamps null: false
    end

    create_table :content_attributions do |t|
      t.integer :attribution_id, null: false, index: true
      t.references :content, polymorphic: true, index: true, null: false
    end

    # Really, a "content curation," but that's enough of a default that we leave
    # off the adjective from the name of this table. NOTE: we added a duplicate
    # of all curation fields with name old_*
    create_table :curations do |t|
      t.integer :user_id, null: false, comment: "the curator"
      t.integer :page_content_id, null: false,
        comment: "this should ONLY point to a page_content where the page_id == source_page_id"

      t.integer :trust, null: false, default: 0,
        comment: "enum: unreviewed, trusted, untrusted"
      t.boolean :is_incorrect, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_misidentified, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_hidden, null: false, default: false
      t.boolean :is_duplicate, null: false, default: false,
        comment: "implies hidden"
      t.boolean :is_low_quality, null: false, default: false,
        comment: "implies hidden"

      t.timestamps null: false
    end

    # NOTE: we drop this, later; this will be stored in TraitBank.
    create_table :trait_curations do |t|
      t.string :uri, index: true, unique: true
      t.integer :user_id, null: false, comment: "the curator"

      t.integer :trust, null: false, default: 0,
        comment: "enum: unreviewed, trusted, untrusted"
      t.boolean :is_incorrect, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_misidentified, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_hidden, null: false, default: false
      t.boolean :is_duplicate, null: false, default: false,
        comment: "implies hidden"
      t.boolean :is_low_quality, null: false, default: false,
        comment: "implies hidden"

      t.timestamps null: false
    end

    create_table :sections do |t|
      t.integer :parent_id
      t.integer :position
      t.string :name, null: false,
        comment: "for use either with globalize or as an I18n key"
    end

    create_table :content_sections do |t|
      t.integer :section_id, null: false
      t.references :content, polymorphic: true, index: true, null: false
    end

    # TODO: Move this to TraitBank! *gulp* ... and add an array of section ids
    create_table :uris do |t|
      t.string :uri, null: false, unique: true, index: true
      t.string :name, null: false, comment: "globalize or I18n"
      t.text :definition, comment: "globalize or I18n"
      t.text :comment, comment: "not sure if this is translated, yet"
      t.text :attribution, comment: "globalize or I18n; html format"
      t.boolean :is_hidden_from_overview, null: false, default: false
      t.boolean :is_hidden_from_glossary, null: false, default: false
    end

    # Just a very basic version for now; will extend later. NOTE: the count
    # field was replaced, later.
    create_table :collections do |t|
      t.string :name, null: false
      t.text :description
      t.integer :collection_items_count
    end
    # add_attachment :collections, :icon

    # NOTE: we renamed this to collection_associations and changed the item
    # reference to "associated_id", later.
    create_table :collection_items do |t|
      t.integer :collection_id, null: false, index: true
      t.references :item, polymorphic: true, index: true, null: false
      t.integer :position
    end
    add_index :collection_items, :item_type, name: "item_type_index"

    # NOTE: this was removed in a later migration.
    create_table :collection_item_exemplars do |t|
      t.integer :collection_item_id, null: false, index: true
      t.references :exemplar, polymorphic: true, index: true, null: false
      t.integer :position
    end

    create_table :collections_users, id: false do |t|
      t.integer :user_id, null: false, index: true
      t.integer :collection_id, null: false, index: true
      t.boolean :is_manager, null: false, default: false
    end
  end
end
