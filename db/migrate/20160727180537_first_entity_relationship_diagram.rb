class FirstEntityRelationshipDiagram < ActiveRecord::Migration
  def change
    create_table :languages do |t|
      t.string :code, null: false, limit: 12, index: true, unique: true,
        comment: "ISO 639-3; e.g.: 'eng' ...Note that the NAME of the language will be handled by "\
          "translation, e.g.: I18n.t('languages.' + lang.code)"
      t.string :group, null: false, limit: 12, index: true,
        comment: "ISO 629-1; e.g. 'en', allowing several dialects to be grouped for display, "\
          "when mutually intelligible"
      t.boolean :can_browse_site, null: false, default: false,
        comment: "whether to include this language in the drop-down of langauges with which you "\
          "may browse the site"
    end

    create_table :licenses do |t|
      t.string :name, null: false,
        comment: "was: title; either for Globalize or I18n key"
      t.string :source_url
      t.string :icon_url
      t.boolean :can_be_chosen_by_partners, null: false, default: false

      t.timestamps
    end

    create_table(:resources) do |t|
      t.integer :content_partner_id, null: false, index: true

      t.string :name, null: false, comment: "was: title"
      t.string :url,
        comment: "the URL to download the resource froml; was: accesspoint_url"
      t.text :description
      t.text :notes
      t.integer :nodes_count
      t.boolean :content_trusted_by_default, null: false, default: true,
        comment: "was: vetted"
      t.boolean :browsable, null: false, default: false
      t.boolean :has_duplicate_nodes, null: false, default: false

      t.integer :default_language_id
      t.integer :default_license_id, comment: "was: license_id"
      t.string :default_rights_statement, limit: 300,
        comment: "was: rights_statement"
      t.text :default_rights_holder, comment: "was: rights_holder"
      t.string :node_source_url_template,
        comment: "used to build the so-called outlink url; %%ID%% is replaced with the entry resource_pk; was: outlink_uri"

      t.datetime :last_published_at
      t.integer :last_publish_seconds
      t.string :publish_status, comment: "enum"

      t.integer :dataset_license_id,
        comment: "applies to the set of data itself (not its individual members)"
      t.string :dataset_rights_holder,
        comment: "applies to the set of data itself (not its individual members)"
      t.string :dataset_rights_statement,
        comment: "applies to the set of data itself (not its individual members)"

      t.timestamps
    end
    add_attachment :resources, :icon

    create_table :partners do |t|
      t.string :full_name, null: false
      t.string :short_name, null: false, comment: "was: display_name"
      t.string :homepage_url, comment: "was: partner_url"
      t.text :description
      t.text :notes, comment: "was: project_notes"
      t.text :admin_notes

      t.timestamps
    end
    add_attachment :partners, :icon
    create_join_table :partners, :users

    create_table :nodes do |t|
      t.integer :resource_id, null: false, index: true
      t.integer :page_id, null: false, index: true
      t.integer :rank_id,
        comment: "note that this is neither trustworthy nor 'scientific', but it's useful for matching and for the community."
      t.integer :parent_id, index: true, comment: "null means root node"
      t.integer :lft, index: true,
        comment: "nested set; lft is roughly how many set boundaries are to the left of this node"
      t.integer :rgt, index: true,
        comment: "nested set; rgt is roughly the rightmost set boundary of this node's descendants"

      t.string :scientific_name, comment: "denormalized, italics included"
      t.string :canonical_form, comment: "denormalized, italics included"
      t.string :resource_pk, index: true, null: false,
        comment: "note that if this is missing in the resource, we will set it to the scientific name; was: identifier"
      t.string :source_url,
        comment: "optional dc:source value, should be different from resource.node_source_url_template + resource_pk; "\
          "we currently have 318 partners that provide this"

      t.boolean :is_hidden, null: false, default: false

      t.timestamps
    end

    create_table :node_ancestors do |t|
      t.integer :node_id, index: true, null: false
      t.integer :ancestor_id, index: true, null: false,
        comment: "another node id"
      t.integer :position, null: false,
        comment: "how deep down from the root (0)"

      t.timestamps
    end

    # Since taxon_remarks are relatively rare (1.4M / 40M), I am going to
    # suggest that—if we even want it—we store this in a separate table
    # entirely. No sense in having a text field that is usually empty.
    create_table :taxon_remarks do |t|
      t.integer :node_id, index: true
      t.text :body,
        comment: "may contain original identification, taxon status, rank, name qualifier, author name, and more; "\
          "html-formatted; can be as long as 4K chrs or more; about 1 in 40 resources includes this information"
    end

    create_table :pages do |t|
      t.integer :native_node_id,
        comment: "node ID from Dynamic Working Hierarchy, which we use to get the preferred ancestors, "\
          "children, and names; null implies 'floating' taxon and should only have one node associated"
      t.integer :moved_to_page_id, comment: "moved/merged/split by curator"

      t.timestamps
    end

    # NOTE: this does NOT capture ratings or exemplars, which we need to add,
    # but I need time to think about that!
    create_table :page_contents do |t|
      t.integer :page_id, null: false, index: true,
        comment: "the content is shown on this page."
      t.integer :source_page_id, null: false, index: true,
        comment: "which page the content was *propaged from* (can be == page_id)."
      t.integer :position,
        comment: "the order in which to show the content on the page"
      t.integer :content_id
      t.integer :content_type

      t.integer :associated_added_by_user_id,
        comment: "no resource added this association, it was added manually"

      # Current curation status (see relationships for history):
      t.string :trust, limit: 16, null: false, default: false,
        comment: "enum: trusted, unreviewed, untrusted"
      t.boolean :is_incorrect, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_misidentified, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_hidden, null: false, default: false
      t.boolean :is_duplicate, null: false, default: false,
        comment: "implies hidden"
      t.boolean :is_low_quality, null: false, default: false,
        comment: "implies hidden"

      t.timestamps
    end
    add_index :page_contents, [:content_id, :content_type],
      name: "content_fk_index"

    create_table :vernaculars do |t|
      t.string :string, null: false,
        comment: "note this does NOT need to be unique"
      t.integer :language_id, null: false
      t.integer :node_id, null: false, index: true
      t.integer :page_id, null: false, index: true,
        comment: "denormalized from node; indexed to get all names on page"
      t.boolean :preferred, null: false, default: false,
        comment: "should only be one true per language per page_id"
      t.boolean :preferred_by_resource, null: false, default: false
      t.boolean :is_hidden, null: false, default: false

      t.timestamps
    end
    add_index :vernaculars, [:page_id, :language_id],
      name: "preferred_names_index"

    create_table :scientific_names do |t|
      t.integer :node_id, null: false, index: true
      t.integer :page_id, null: false, index: true,
        comment: "denormalized from node; indexed to get all names for a page"
      t.string :type, null: false, default: "prefered_scientific",
        comment: "the string provided by the resource to describe the name type; "\
          "see scientific_name.rb for examples"
      t.string :italicized, null: false,
        comment: "finding/applying the italicized pieces out of the normalized form"
      t.string :canonical_form, null: false,
        comment: "pulling out only the canonical form from the normalized form"

      t.timestamps
    end

    create_table :image_info do |t|
      t.integer :image_id, null: false, index: true, unique: true,
        comment: "not polymorphic--only needed for images"
      t.string :original_size, null: false, limit: 12,
        comment: "e.g.: 1600x1200"
      t.string :large_size, limit: 12, comment: "e.g.: 1024x768"
      t.string :medium_size, limit: 12, comment: "e.g.: 600x400"
      t.string :small_size, limit: 12, comment: "e.g.: 100x80"
      t.decimal :crop_x, precision: 5, scale: 2,
        comment: "left edge, as a percent"
      t.decimal :crop_y, precision: 5, scale: 2,
        comment: "top edge, as a percent"
      t.decimal :crop_w, precision: 5, scale: 2,
        comment: "width (and thus height), as a percent"

      t.timestamps
    end

    # NOTE: the FK is in the content table, which helps us know if there IS a
    # location for a given piece of content.
    create_table :content_locations do |t|
      t.string :location
      t.decimal :longitude, precision: 64, scale: 12
      t.decimal :latitude, precision: 64, scale: 12
      t.decimal :altitude, precision: 64, scale: 12
      t.text :spatial_location
    end

    create_table :javascripts do |t|
      t.string :filename, null: false
    end

    create_table :stylesheets do |t|
      t.string :filename, null: false
    end

    create_table :media do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.string :provider_type, null: false, limit: 10,
        comment: "User or Resource"
      t.integer :provider_id, null: false

      t.string :media_type, null: false, default: "image",
        comment: "enum: image, video, sound"
      t.string :format, null: false, default: "jpg",
        comment: "enum: jpg, youtube, flash, vimeo, mp3, ogg, wav"

      t.integer :license_id, null: false
      t.integer :language_id
      t.integer :location_id
      t.integer :sytlesheet_id
      t.integer :javascript_id
      t.integer :bibliographic_citation_id

      t.text :owner, null: false,
        comment: "html; was rights_holder; current longest is 493; if missing, *must* be populated "\
          "with another attribution agent or the resource name: we MUST show an owner"

      t.string :name, comment: "was: title"
      t.string :source_url
      t.string :description, comment: "html; run through namelinks"
      t.string :base_url, null: false,
        comment: "for images, you will add size info to this; was: object_url"

      t.timestamps
    end
    add_index :media, [:provider_id, :provider_type],
      name: "provider_fk_index"

    create_table :articles do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.string :provider_type, null: false, limit: 10,
        comment: "User or Resource"
      t.integer :provider_id, null: false

      t.integer :license_id, null: false
      t.integer :language_id
      t.integer :location_id
      t.integer :sytlesheet_id
      t.integer :javascript_id
      t.integer :bibliographic_citation_id

      t.text :owner, null: false,
        comment: "html; was rights_holder; current longest is 493; if missing, *must* be populated "\
          "with another attribution agent or the resource name: we MUST show an owner"

      t.string :name, comment: "was: title"
      t.string :source_url
      t.string :body, null: false,
        comment: "html; run through namelinks; was description_linked"

      t.timestamps
    end
    add_index :articles, [:provider_id, :provider_type],
      name: "provider_fk_index"

    create_table :links do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.string :provider_type, null: false, limit: 10,
        comment: "User or Resource"
      t.integer :provider_id, null: false

      t.integer :language_id

      t.string :name, comment: "was: title"
      t.string :source_url
      t.string :description, null: false,
        comment: "html; run through namelinks; was description_linked"
      t.string :base_url, null: false,
        comment: "icon; you will add size info to this; was: object_url"

      t.timestamps
    end
    add_index :links, [:provider_id, :provider_type],
      name: "provider_fk_index"

    create_table :maps do |t|
      t.string :guid, null: false, index: true
      t.string :resource_pk, null: false, comment: "was: identifier"

      t.string :provider_type, null: false, limit: 10,
        comment: "User or Resource"
      t.integer :provider_id, null: false

      t.integer :license_id, null: false
      t.integer :language_id
      t.integer :sytlesheet_id
      t.integer :javascript_id
      t.integer :bibliographic_citation_id

      t.text :owner, null: false,
        comment: "html; was rights_holder; current longest is 493; if missing, *must* be populated "\
          "with another attribution agent or the resource name: we MUST show an owner"

      t.string :name, comment: "was: title"
      t.string :source_url
      t.string :base_url, null: false,
        comment: "icon; you will add size info to this; was: object_url"


      t.timestamps
    end
    add_index :maps, [:provider_id, :provider_type],
      name: "provider_fk_index"

    # There are currently 1,084,941 published data objects with a non-empty
    # citation, out of 7,785,934 objects. Of those, there is a lot of
    # duplication, so I'm making this its own table.
    create_table :bibliographic_citations do |t|
      t.text :body, comment: "html; can be *quite* large (over 10K chrs)"

      t.timestamps
    end

    create_table :references do |t|
      t.text :body, comment: "html; can be *quite* large (over 10K chrs)"

      t.timestamps
    end

    create_table :contents_references do |t|
      t.integer :reference_id, null: false, index: true
      t.integer :content_id, null: false
      t.string :content_type, null: false
    end
    add_index :contents_references, [:content_id, :content_type],
      name: "content_fk_index"

    create_table :attributions do |t|
      t.string :role, null: false, index: true,
        comment: "passed to I18n.t"
      t.text :value, null: false, comment: "html"

      t.timestamps
    end

    create_table :attributions_contents do |t|
      t.integer :attribution_id, null: false, index: true
      t.integer :content_id, null: false
      t.string :content_type, null: false
    end
    add_index :attributions_contents, [:content_id, :content_type],
      name: "content_fk_index"

    create_table :trait_curations do |t|
      t.string :uri, index: true, unique: true

      t.string :trust, limit: 16, null: false, default: false,
        comment: "enum: trusted, unreviewed, untrusted"
      t.boolean :is_incorrect, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_misidentified, null: false, default: false,
        comment: "implies untrusted"
      t.boolean :is_hidden, null: false, default: false
      t.boolean :is_duplicate, null: false, default: false,
        comment: "implies hidden"
      t.boolean :is_low_quality, null: false, default: false,
        comment: "implies hidden"

      t.timestamps
    end

    create_table :sections do |t|
      t.integer :parent_id
      t.integer :position
      t.string :name, null: false,
        comment: "for use either with globalize or as an I18n key"
    end

    create_table :contents_sections do |t|
      t.integer :section_id, null: false
      t.integer :content_id, null: false
      t.string :content_type, null: false
    end
    add_index :contents_sections, [:content_id, :content_type],
      name: "content_fk_index"

    create_table :uris do |t|
      t.string :uri, null: false, unique: true, index: true
      t.string :name, null: false, comment: "globalize or I18n"
      t.text :definition, comment: "globalize or I18n"
      t.text :comment, comment: "not sure if this is translated, yet"
      t.text :attribution, comment: "globalize or I18n"
      t.boolean :is_hidden_from_overview, null: false, default: false
      t.boolean :is_hidden_from_glossary, null: false, default: false
    end
  end
end
