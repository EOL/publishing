class CreateVernacularPreferences < ActiveRecord::Migration
  def change
    create_table :vernacular_preferences do |t|
      t.integer :user_id, null: false
      # NOTE: vernacular_id indexed in case we want to look up the name on the names tab.
      t.integer :vernacular_id, null: false, index: true
      # NOTE: resource_id indexed because we query on it for a republish.
      t.integer :resource_id, null: false, index: true, comment: "DENORMALIZED copy, in case we lose the original."
      t.integer :language_id, comment: "DENORMALIZED copy, in case we lose the original."
      t.integer :page_id, comment: "DENORMALIZED copy, because we need to look up overrides using it."
      t.integer :overridden_by_id, comment: "NOTE that the last curation (always) wins."
      t.string :string, null: false, comment: "DENORMALIZED copy, in case we lose the original."
      t.timestamps
    end
    add_index :vernacular_preferences, [:page_id, :language_id], name: 'override_lookup'
  end
end
