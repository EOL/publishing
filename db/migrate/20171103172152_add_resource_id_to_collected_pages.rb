class AddResourceIdToCollectedPages < ActiveRecord::Migration
  def change
    add_column :collected_pages, :resource_id, :integer, comment: 'denormalized: used for simplified cleanup.'
  end
end
