class CreateOccurrenceMaps < ActiveRecord::Migration
  def change
    # NOTE: this is (arguably) denormalized from nodes, because we don't want to
    # *harvest* this content yet. A specific import script will need to be run
    # to get these data. It's assumed that if a record exists for this page, the
    # JSON with the occurrence data will be in the "public/maps/%{page.id %
    # 100}" directory. Things will break mightily if it's missing.
    create_table :occurrence_maps do |t|
      t.integer :resource_id
      t.integer :page_id
      t.string :url, limit: 256
    end
  end
end
