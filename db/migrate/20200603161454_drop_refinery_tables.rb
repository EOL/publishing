class DropRefineryTables < ActiveRecord::Migration[5.2]
  def change
    drop_table :refinery_image_translations
    drop_table :refinery_images
    drop_table :refinery_page_part_translations
    drop_table :refinery_page_parts
    drop_table :refinery_page_translations
    drop_table :refinery_pages
    drop_table :refinery_resource_translations
    drop_table :refinery_resources
  end
end
