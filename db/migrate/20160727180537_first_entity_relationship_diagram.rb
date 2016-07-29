class FirstEntityRelationshipDiagram < ActiveRecord::Migration
  def change
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
      t.string :default_rights_statement, comment: "was: rights_statement"
      t.string :default_rights_holder, comment: "was: rights_holder"
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
      t.integer :node_id, null: false
      t.integer :page_id, null: false, comment: "denormalized from node"
      t.boolean :preferred, null: false, default: false,
        comment: "should only be one true per language per page_id"
      t.boolean :preferred_by_resource, null: false, default: false
      t.boolean :is_hidden, null: false, default: false
    end

    create_table :scientific_names do |t|
      t.string :type, null: false, default: "prefered_scientific",
        comment: "the string provided by the resource to describe the name type; "\
          "see scientific_name.rb for examples"
      t.string :italicized, null: false,
        comment: "finding/applying the italicized pieces out of the normalized form"
      t.string :canonical_form, null: false,
        comment: "pulling out only the canonical form from the normalized form"
    end
  end
end
