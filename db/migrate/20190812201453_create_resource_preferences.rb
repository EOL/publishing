class CreateResourcePreferences < ActiveRecord::Migration
  def change
    create_table :resource_preferences do |t|
      t.integer :resource_id, null: false
      t.string :class_name, null: false, index: true
      t.integer :position, null: false
    end
    if resource = Resource.where(abbr: 'English_Vernacul').first
      ResourcePreference.create(resource_id: resource.id, class_name: 'Vernacular', position: 1)
    end
    if resource = Resource.where(abbr: 'wikidata').first
      ResourcePreference.create(resource_id: resource.id, class_name: 'Vernacular', position: 2)
    end
  end
end
