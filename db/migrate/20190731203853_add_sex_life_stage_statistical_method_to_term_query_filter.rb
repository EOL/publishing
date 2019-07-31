class AddSexLifeStageStatisticalMethodToTermQueryFilter < ActiveRecord::Migration
  def change
    add_column :term_query_filters, :sex_uri, :string
    add_column :term_query_filters, :life_stage_uri, :string
    add_column :term_query_filters, :statistical_method_uri, :string
  end
end
