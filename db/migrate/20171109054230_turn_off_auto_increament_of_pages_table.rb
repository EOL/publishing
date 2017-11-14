class TurnOffAutoIncreamentOfPagesTable < ActiveRecord::Migration
  def change
    change_column :pages, :id, :integer
  end
end
