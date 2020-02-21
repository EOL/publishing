class TaxonomicStatusChangeDefaultValueOfIsPreferred < ActiveRecord::Migration[4.2]
  def change
    change_column_default(:taxonomic_statuses, :is_preferred, false)
    TaxonomicStatus.update_all(is_preferred: false)
    TaxonomicStatus.where(name: ["accepted", "preferred", "valid"]).update_all(is_preferred: true)
  end
end
