class AddFieldsToOtherContentToo < ActiveRecord::Migration[4.2]
  def change
    add_column :articles, :page_id, :integer, comment: 'This is the source page, which is available from the harvest and can be used to rebuild page_contents'
    add_column :links, :page_id, :integer, comment: 'This is the source page, which is available from the harvest and can be used to rebuild page_contents'
  end
end
