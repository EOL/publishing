class AddMediaSubtypeToPageContents < ActiveRecord::Migration
  def change
    add_column :page_contents, :content_subclass, :integer, default: 0
    PageContent.connection.execute(
      'UPDATE page_contents pc LEFT JOIN media m ON pc.content_id = m.id '\
        'SET pc.content_subclass = m.subclass WHERE pc.content_type = "Medium"'
    )
    # YOU WERE HERE: This is all fine and dandy, but you'll also have to update the harvester to set and import this
    # column, and make sure that any content-inserting code set this value where appropriate (I think harvesting may be
    # the only case, but check).
  end
end
