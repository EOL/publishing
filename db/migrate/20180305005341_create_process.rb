class CreateProcess < ActiveRecord::Migration[4.2]
  def change
    create_table :processes do |t|
      t.integer :resource_id, null: false
      t.string :error
      t.text :trace
      t.datetime :created_at
      t.datetime :stopped_at
    end

    create_table :warnings do |t|
      t.integer :resource_id, null: false
      t.string :message
    end

    create_table :tasks do |t|
      t.integer :process_id
      t.string :method
      t.text :info
      t.string :progress
      t.string :summary
      t.datetime :created_at
      t.datetime :exited_at
    end
  end
end
