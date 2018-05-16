class AddPageRichnessToPages < ActiveRecord::Migration
  def change
    add_column :pages, :page_richness, :integer
  end
end
