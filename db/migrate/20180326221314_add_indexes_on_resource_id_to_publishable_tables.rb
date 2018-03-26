# 20180326221314
class AddIndexesOnResourceIdToPublishableTables < ActiveRecord::Migration
  def change
    add_index :articles, :resource_id
    add_index :articles, :harv_db_id
    add_index :media, :resource_id
    add_index :media, :harv_db_id
    add_index :attributions, :resource_id
    add_index :attributions, :content_id
    add_index :image_info, :resource_id
    add_index :image_info, :harv_db_id
    add_index :references, :resource_id
    add_index :references, :parent_id
    add_index :vernaculars, :resource_id
    add_index :vernaculars, :harv_db_id
    add_index :node_ancestors, :resource_id
    add_index :node_ancestors, :harv_db_id
    add_index :scientific_names, :resource_id
    add_index :scientific_names, :harv_db_id
    add_index :referents, :resource_id
    add_index :referents, :harv_db_id
  end
end
