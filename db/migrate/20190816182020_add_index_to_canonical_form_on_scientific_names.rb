class AddIndexToCanonicalFormOnScientificNames < ActiveRecord::Migration
  def change
    add_index :scientific_names, :canonical_form
  end
end
