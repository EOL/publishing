class RemoveUserDownloadsQueryColumns < ActiveRecord::Migration[4.2]
  def change
    change_table :user_downloads do |t|
      t.remove :clade
      t.remove :object_terms
      t.remove :predicates
    end
  end
end
