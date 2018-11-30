class CreatePageRedirects < ActiveRecord::Migration
  def change
    create_table :page_redirects do |t|
      t.integer :redirect_to_id
    end
    PageRedirect.create(id: 451180, redirect_to_id: 46451161)
  end
end
