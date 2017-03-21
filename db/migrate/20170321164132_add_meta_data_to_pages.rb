# 20170321164132
class AddMetaDataToPages < ActiveRecord::Migration
  def self.up
    add_column :pages, :page_contents_count, :integer, :null => false, :default => 0
    add_column :pages, :media_count, :integer, :null => false, :default => 0
    add_column :pages, :articles_count, :integer, :null => false, :default => 0
    add_column :pages, :maps_count, :integer, :null => false, :default => 0
    add_column :pages, :traits_count, :integer, :null => false, :default => 0
    add_column :pages, :nodes_count, :integer, :null => false, :default => 0
    add_column :pages, :vernaculars_count, :integer, :null => false, :default => 0
    add_column :pages, :scientific_names_count, :integer, :null => false, :default => 0
    add_column :pages, :referents_count, :integer, :null => false, :default => 0
    # These are not technically counts, but they are metadata that are associated with counts on pages, so:
    add_column :pages, :species_count, :integer, :null => false, :default => 0
    add_column :pages, :is_extinct, :boolean, null: false, default: false
    add_column :pages, :iucn_status, :string, length: 32, comment: "I18n key"
    add_column :pages, :trophic_strategy, :string, length: 32, comment: "I18n key"
    add_column :pages, :geographic_context, :string, length: 32, comment: "I18n key"
    add_column :pages, :habitat, :string, length: 32, comment: "I18n key"
  end

  def self.down
    remove_column :pages, :media_count
    remove_column :pages, :articles_count
    remove_column :pages, :maps_count
    remove_column :pages, :traits_count
    remove_column :pages, :nodes_count
    remove_column :pages, :vernaculars_count
    remove_column :pages, :scientific_names_count
    remove_column :pages, :referents_count
    remove_column :pages, :species_count
    remove_column :pages, :is_extinct
    remove_column :pages, :iucn_status
    remove_column :pages, :trophic_strategy
    remove_column :pages, :geographic_context
    remove_column :pages, :habitat
  end
end
