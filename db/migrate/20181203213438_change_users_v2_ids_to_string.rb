class ChangeUsersV2IdsToString < ActiveRecord::Migration
  def change
    add_column :users, :v2_ids, :text, comment: 'a semicolon-delimited array of ids used by this email address in v2'
    add_column :users, :curator_level, :integer
    remove_column :users, :v2_id # NOTE: it was never used at this point, safe to simply drop it.
  end
end
