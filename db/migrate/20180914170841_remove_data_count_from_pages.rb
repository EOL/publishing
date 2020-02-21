class RemoveDataCountFromPages < ActiveRecord::Migration[4.2]
  def change
    remove_column :pages, :data_count
  end
end
