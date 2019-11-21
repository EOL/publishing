class UserDownload < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_downloads
  belongs_to :term_query, dependent: :delete # delete because destroy creates bidirectional dependent: :destroy, which causes stack overflow, and we only care about running callbacks here
  has_one :download_error, class_name: "UserDownload::Error", dependent: :destroy # Weird exceptions in delayed_job when this was set to just "error".
  validates_presence_of :user_id
  validates_presence_of :count
  validates_presence_of :term_query
  validates_presence_of :search_url

  after_destroy :delete_file

  enum status: { created: 0, completed: 1, failed: 2 }

  # NOTE: should be created by populating clade, object_terms, predicates, and
  # count. Also NOTE that using after_commit avoids racing conditions where
  # after_create may be called prematurely.
  after_commit :background_build, on: :create

  # TODO: this should be set up in a regular task.
  def self.expire_old
    where(expired_at: null).where("created_at < ?", 2.weeks.ago).
      update_all(expired_at: Time.now)
  end

  # NOTE: for timing reasons, this does NOT #save the current model, you should do that yourself.
  def fail(message, backtrace)
    self.transaction do
      self.status = :failed
      self.completed_at = Time.now # Yes, this is duplicated from #background_build, but it's safer to do so.
      build_download_error({message: message, backtrace: backtrace})
    end
  end

private
  def background_build
    begin
      downloader = TraitBank::DataDownload.new(term_query, count, search_url)
      self.filename = downloader.background_build
      self.status = :completed
    rescue => e
      Rails.logger.error("!! ERROR in background_build for User Download #{id}")
      Rails.logger.error("!! #{e.message}")
      Rails.logger.error("!! #{e.backtrace.join('->')}")
      fail(e.message, e.backtrace.join("\n"))
      raise e
    ensure
      self.completed_at = Time.now
      save! # NOTE: this could fail and we lose everything.
    end
  end
  handle_asynchronously :background_build, :queue => "download"

  def delete_file
    if self.completed? && !self.filename.blank?
      path = TraitBank::DataDownload.path.join(self.filename)
      begin
        File.delete(path)
      rescue => e
        Rails.logger.error("Failed to delete user download file #{path}", e)
      end
    end
  end
end
