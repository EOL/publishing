class AddAttributionToScientificNames < ActiveRecord::Migration
  def change
    add_column :scientific_names, :attribution, :text
  end
end
