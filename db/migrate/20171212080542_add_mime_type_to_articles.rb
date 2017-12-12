class AddMimeTypeToArticles < ActiveRecord::Migration
  def change
    add_column :articles, :mime_type, :integer
  end
end
