# This migration comes from refinery_page_resources (originally 20110511215016)
class TranslatePageResourceCaptions < ActiveRecord::Migration
  def up
    add_column :refinery_page_resources, :id, :primary_key

    Refinery::PageResource.reset_column_information
    unless defined?(Refinery::PageResource::Translation) && Refinery::PageResource::Translation.table_exists?
      Refinery::PageResource.create_translation_table!({
        :caption => :text
      }, {
        :migrate_data => true
      })
    end
  end

  def down
    Refinery::PageResource.reset_column_information

    Refinery::PageResource.drop_translation_table! :migrate_data => true

    remove_column Refinery::PageResource.table_name, :id
  end
end
