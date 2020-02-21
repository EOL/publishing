class AddPageRichnessToPages < ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :page_richness, :integer
  end
end
