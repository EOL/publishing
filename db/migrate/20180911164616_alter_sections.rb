class AlterSections < ActiveRecord::Migration
  def up
    # NOTE: at the time this migration is run, there are no sections in the DB, so it's safe to modify without
    # considering reprocussions.
    remove_column :sections, :parent_id
  end

  def down
    add_column :sections, :parent_id, :integer
  end
end
