class RemoveDataCountFromPages < ActiveRecord::Migration
  def change
    remove_column :pages, :data_count
  end
end
