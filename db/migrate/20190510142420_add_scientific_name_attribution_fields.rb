class AddScientificNameAttributionFields < ActiveRecord::Migration[4.2]
  def change
    add_column :scientific_names, :dataset_name, :text, comment: 'http://rs.tdwg.org/dwc/terms/datasetName'
    add_column :scientific_names, :name_according_to, :text, comment: 'http://rs.tdwg.org/dwc/terms/nameAccordingTo'
  end
end
