class AddVisitedAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :visited_at, :datetime
  end
end
