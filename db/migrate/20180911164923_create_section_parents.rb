class CreateSectionParents < ActiveRecord::Migration[4.2]
  def change
    create_table :section_parents do |t|
      t.integer :section_id
      t.integer :parent_id
    end
    DefaultSections.create
  end
end
