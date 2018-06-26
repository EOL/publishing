class AddResultTypeToTermQuery < ActiveRecord::Migration
  def change
    add_column :term_queries, :result_type, :integer
  end
end
