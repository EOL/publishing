class AddIndexToCanonicalFormOnScientificNames < ActiveRecord::Migration[4.2]
  def change
    add_index :scientific_names, :canonical_form
  end
end
