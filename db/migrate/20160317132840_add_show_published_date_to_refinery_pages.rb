class AddShowPublishedDateToRefineryPages < ActiveRecord::Migration
  def change
    add_column :refinery_pages, :show_date, :boolean
  end
end
