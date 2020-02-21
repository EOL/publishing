class AddSortToCollection < ActiveRecord::Migration[4.2]
  def change
    add_column :collections, :default_sort, :integer, default: 0
  end
end
