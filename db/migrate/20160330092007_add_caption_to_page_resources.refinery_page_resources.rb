# This migration comes from refinery_page_resources (originally 20101014230042)
class AddCaptionToPageResources < ActiveRecord::Migration
  def change
    add_column :refinery_page_resources, :caption, :text
  end
end
