class AddResourceIdToContentSections < ActiveRecord::Migration
  def change
    add_column :content_sections, :resource_id, :integer, null: false
  end
end
