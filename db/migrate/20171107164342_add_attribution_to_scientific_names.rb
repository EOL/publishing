class AddAttributionToScientificNames < ActiveRecord::Migration[4.2]
  def change
    add_column :scientific_names, :attribution, :text
  end
end
