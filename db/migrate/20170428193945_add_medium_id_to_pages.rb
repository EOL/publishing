# 20170428193945
class AddMediumIdToPages < ActiveRecord::Migration[4.2]
  def change
    add_column(:pages, :medium_id, :integer,
      comment: "denormalized id of the top medium for this page: the icon.")
    # WARNING: this will be quite slow with a large database. Sorry.
    Searchkick.disable_callbacks
    Page.all.select(:id).find_each do |page|
      page.update_attribute(:medium_id, page.media.first.id) unless page.media.empty?
    end
    Searchkick.enable_callbacks
  end
end
