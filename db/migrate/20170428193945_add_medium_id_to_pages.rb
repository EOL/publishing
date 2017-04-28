# 20170428193945
class AddMediumIdToPages < ActiveRecord::Migration
  def change
    add_column(:pages, :medium_id, :integer,
      comment: "denormalized id of the top medium for this page: the icon.")
    # WARNING: this will be quite slow with a large database. Sorry.
    Sunspot.session = Sunspot::Rails::StubSessionProxy.new(Sunspot.session)
    Page.all.select(:id).find_each do |page|
      page.update_attribute(:medium_id, page.media.first.id) unless page.media.empty?
    end
    Sunspot.session = Sunspot.session.original_session
  end
end
