class AddContentIdIndexToPageContents < ActiveRecord::Migration
  def change
    add_index :page_contents, :content_id
  end
end
