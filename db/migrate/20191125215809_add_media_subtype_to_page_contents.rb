# 20191125215809
class AddMediaSubtypeToPageContents < ActiveRecord::Migration[4.2]
  def up
    default = Medium.subclasses[:image] # Probably 0, but let's be safe.
    add_column :page_contents, :content_subclass, :integer, default: default
    Medium.subclasses.values.each do |subclass|
      next if subclass == default
      Medium.where(subclass: subclass).select(['id']).find_in_batches do |batch|
        ids = batch.map(&:id)
        PageContent.where(content_type: 'Medium', content_id: ids).update_all(content_subclass: subclass)
      end
    end
    # YOU WERE HERE: This is all fine and dandy, but you'll also have to update the harvester to set and import this
    # column, and make sure that any content-inserting code set this value where appropriate (I think harvesting may be
    # the only case, but check).
  end

  def down
    remove_column :page_contents, :content_subclass
  end
end
