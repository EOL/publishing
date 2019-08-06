class RenameTermSearchQueryLifeStage < ActiveRecord::Migration
  def change
    rename_column :term_query_filters, :life_stage_uri, :lifestage_uri
  end
end
