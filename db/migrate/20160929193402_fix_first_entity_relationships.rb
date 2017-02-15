class FixFirstEntityRelationships < ActiveRecord::Migration
  def up
    remove_column(:resources, :default_language_id)
    remove_column(:resources, :default_license_id)
    remove_column(:resources, :default_rights_statement)
    remove_column(:resources, :default_rights_holder)

    remove_column(:vernaculars, :is_hidden)
    add_column(:vernaculars, :trust, :integer, null: false, default: 0,
      comment: "enum: unreviewed, trusted, untrusted")

    add_column(:media, :unmodified_url, :string,
      comment: "This is the unmodified, original image that we store locally; includes extension (unlike base_url)")
    add_column(:media, :source_page_url, :string,
      comment: "This is where the 'view original' link takes you (could be an remote image or a webpage)")
    add_column(:media, :resource_id, :integer)
    Medium.connection.execute("UPDATE media SET resource_id = provider_id WHERE provider_type = 'Resource'")
    change_column(:media, :resource_id, :integer, :null => false, index: true)
    remove_index(:media, name: "index_media_on_provider_type_and_provider_id")
    remove_column(:media, :provider_type)
    remove_column(:media, :provider_id)
    # NOT reversible, but it's just a comment, shouldn't need to:
    change_column(:media, :subclass, :string, null: false, default: 0, index: true,
      comment: "enum: image, video, sound, map, js_map")

    add_column(:articles, :resource_id, :integer)
    Article.connection.execute("UPDATE articles SET resource_id = provider_id WHERE provider_type = 'Resource'")
    remove_column(:articles, :provider_type)
    remove_column(:articles, :provider_id)

    add_column(:links, :resource_id, :integer)
    Link.connection.execute("UPDATE links SET resource_id = provider_id WHERE provider_type = 'Resource'")
    remove_column(:links, :provider_type)
    remove_column(:links, :provider_id)
    rename_column(:links, :base_url, :icon_url)

    drop_table :maps
    # This is not really the "right" thing to do, but at this early stage (where
    # we don't show maps anyway), it will suffice:
    PageContent.where(content_type: "Map").delete_all

    # NOTE: Aaaaaand... we actually undid this in a subsequent migration,
    # restoring it to the way it was. Alas!
    create_join_table(:articles, :references) do |t|
      t.index :article_id
    end
    Article.connection.execute("INSERT INTO articles_references (article_id, "\
      "reference_id) SELECT content_id, reference_id FROM content_references "\
      "WHERE content_type = 'Article'")
    drop_table :content_references

    add_column(:content_attributions, :role_id, :integer, null: false, index: true)
    add_column(:content_attributions, :value, :text, null: false, comment: "html")
    add_column(:content_attributions, :created_at, :datetime)
    add_column(:content_attributions, :updated_at, :datetime)
    # NOTE: we "should" have a pretty complex query here to update
    # content_attributions, but at the time of this writing, it wasn't
    # populated. So I'm going to skip the work. :)

    drop_table :attributions
    rename_table :content_attributions, :attributions

    add_column(:curations, :old_trust, :integer, null: false, default: 0,
      comment: "enum: unreviewed, trusted, untrusted")
    add_column(:curations, :old_is_incorrect, :boolean, null: false,
      default: false, comment: "implies untrusted")
    add_column(:curations, :old_is_misidentified, :boolean, null: false,
      default: false, comment: "implies untrusted")
    add_column(:curations, :old_is_hidden, :boolean, null: false, default: false)
    add_column(:curations, :old_is_duplicate, :boolean, null: false,
      default: false, comment: "implies hidden")
    add_column(:curations, :old_is_low_quality, :boolean, null: false,
      default: false, comment: "implies hidden")

    drop_table :trait_curations

    rename_table :collection_items, :collection_associations
    add_column(:collection_associations, :associated_id, :integer, index: true)
    remove_index(:collection_associations, name: "item_type_index")
    remove_column(:collection_associations, :item_type)
    remove_column(:collection_associations, :item_id)
    CollectionAssociation.delete_all # We don't have any collected collections!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
