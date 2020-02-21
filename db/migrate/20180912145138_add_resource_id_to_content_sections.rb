class AddResourceIdToContentSections < ActiveRecord::Migration[4.2]
  def change
    add_column :content_sections, :resource_id, :integer, null: false
  end
end
