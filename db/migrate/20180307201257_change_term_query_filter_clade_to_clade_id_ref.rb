class ChangeTermQueryFilterCladeToCladeIdRef < ActiveRecord::Migration[4.2]
  def change
    remove_column :term_queries, :clade
    add_column :term_queries, :clade_id, :integer, :index => true
  end
end
