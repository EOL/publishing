class CreateV2Users < ActiveRecord::Migration
  def change
    create_table :v2_users do |t|
      t.integer :user_id, null: false, comment: "The 'id' field is the v2 user id, THIS column is the v3 user id."
    end
    add_column :collections, :v2_id, :integer, comment: 'The ID of the collection in V2 database, if any.'
    User.where('v2_ids IS NOT NULL').find_each do |user|
      user.v2_ids.split(';').each do |old_id|
        V2User.create(id: old_id, user_id: user.id)
      end
    end
  end
end
