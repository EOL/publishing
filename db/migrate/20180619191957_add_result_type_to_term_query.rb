class AddResultTypeToTermQuery < ActiveRecord::Migration[4.2]
  def change
    add_column :term_queries, :result_type, :integer
  end
end
