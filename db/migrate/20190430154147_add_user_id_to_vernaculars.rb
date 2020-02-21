class AddUserIdToVernaculars < ActiveRecord::Migration[4.2]
  def change
    add_column :vernaculars, :user_id, :integer, comment: "If non-null, a user contributed this name."
  end
end
