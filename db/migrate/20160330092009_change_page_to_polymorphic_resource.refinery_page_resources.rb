# This migration comes from refinery_page_resources (originally 20121003052435)
class ChangePageToPolymorphicResource < ActiveRecord::Migration
  def change
    add_column :refinery_page_resources, :page_type, :string, :default => "page"
  end
end
