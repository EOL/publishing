class AddContentIdIndexToPageContents < ActiveRecord::Migration[4.2]
  def change
    add_index :page_contents, :content_id
  end
end
