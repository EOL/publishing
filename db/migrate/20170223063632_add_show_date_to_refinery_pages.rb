class AddShowDateToRefineryPages < ActiveRecord::Migration[4.2]
  def change
    add_column :refinery_pages, :show_date, :boolean
  end
end
