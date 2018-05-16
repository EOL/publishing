class AddSortToCollection < ActiveRecord::Migration
  def change
    add_column :collections, :default_sort, :integer, default: 0
  end
end
