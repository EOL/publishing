class CreateFallbackLocales < ActiveRecord::Migration[5.2]
  def change
    create_table :fallback_locales do |t|
      t.integer :locale_id
      t.integer :fallback_locale_id
      t.integer :position

      t.timestamps
    end
    add_index :fallback_locales, :locale_id
  end
end
