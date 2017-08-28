class UserDownload < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_downloads

  # NOTE: we can store arrays in these fields, so we serialize them:
  serialize :object_terms
  serialize :predicates

  # NOTE: should be created by populating clade, object_terms, predicates, and
  # count. Also NOTE that using after_commit avoids racing conditions where
  # after_create may be called prematurely.
  after_commit :background_build, on: :create

  # TODO: this should be set up in a regular task.
  def self.expire_old
    where(expired_at: null).where("created_at < ?", 2.weeks.ago).
      update_all(expired_at: Time.now)
  end

  # Helper method to convert things to the search page format:
  def options
    {
      clade: self[:clade],
      object_term: self[:object_terms],
      predicate: self[:predicates]
    }
  end

private

  def background_build
    downloader = TraitBank::DataDownload.new(options.merge(count: self[:count]))
    self[:filename] = downloader.background_build
    self[:completed_at] = Time.now
    save!
  end
  handle_asynchronously :background_build

end
