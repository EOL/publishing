class RenameTermSearchQueryLifeStage < ActiveRecord::Migration[4.2]
  def change
    rename_column :term_query_filters, :life_stage_uri, :lifestage_uri
  end
end
