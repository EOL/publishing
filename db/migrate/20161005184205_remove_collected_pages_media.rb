class RemoveCollectedPagesMedia < ActiveRecord::Migration[4.2]
  def up
    # In theory, we "should" preserve the collected pages medium by adding it to
    # the collected_pages_media table, but that's silly, because we're still
    # only testing. Skipping that extra work.
    remove_column :collected_pages, :medium_id
    remove_column :collected_pages, :scientific_name_id
    remove_column :collected_pages, :vernacular_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
