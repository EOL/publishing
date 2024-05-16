class RenamePageContentsContentSubcategory < ActiveRecord::Migration[5.2]
  def change
    rename_column :page_contents, :content_subclass, :content_subcategory
  end
end
