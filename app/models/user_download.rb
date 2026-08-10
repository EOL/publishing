class UserDownload < ApplicationRecord
  belongs_to :user, inverse_of: :user_downloads
  belongs_to :term_query
  has_one :download_error, class_name: "UserDownload::Error", dependent: :destroy # Weird exceptions in delayed_job when this was set to just "error".
  validates_presence_of :count
  validates_presence_of :term_query
  validates_presence_of :search_url

  after_destroy :delete_file

  accepts_nested_attributes_for :term_query

  enum status: { created: 0, completed: 1, failed: 2 }
  enum duplication: { original: 0, duplicate: 1 }

  scope :pending, -> do
    where("created_at >= ?", EXPIRATION_TIME.ago)
      .where(status: :created)
  end

  scope :for_user_display, -> do
    where("(created_at >= ? AND status != ?) OR status = ?", EXPIRATION_TIME.ago, UserDownload.statuses[:completed], UserDownload.statuses[:completed])
  end

  EXPIRATION_TIME = 90.days
  VERSION = 1 # IMPORTANT: Increment this when making changes where you don't want older downloads to be reused

  class << self
    def self.expire_old
      where(expired_at: nil).where("created_at < ?", EXPIRATION_TIME.ago).each do |dl|
        dl.update(expired_at: Time.now)
        dl.delete_file if dl.file_exists?
      end
    end

    # ADMIN method (not called in code) to clear out jobs both in the DB and in Delayed::Job
    def all_clear
      pending.delete_all
      Delayed::Job.where(queue: :download).delete_all
    end
    alias_method :all_clear!, :all_clear

    def create_and_run_if_needed!(ud_attributes, new_query, options)
      download = UserDownload.new(ud_attributes.merge(version: VERSION))
      query = TermQuery.find_or_save!(new_query)
      download.term_query = query

      existing_download = !options[:force_new] && completed_originals_for_saved_query(query).first

      if existing_download&.file_exists?
        download.filename = existing_download.filename
        download.status = :completed
        download.duplication = :duplicate
        download.completed_at = Time.now
      else
        download.duplication = :original
      end

      download.save!

      if !download.completed?
        download.background_build_with_delay
      end

      download
    end

    def downloads_for_query(term_query)
      existing_query = TermQuery.find_saved(term_query)
      return none unless existing_query

      existing_query.user_downloads
    end

    def completed_originals_for_saved_query(saved_query)
      saved_query.user_downloads
        .where(status: :completed, expired_at: nil, duplication: :original)
        .where("created_at >= ?", EXPIRATION_TIME.ago)
        .where(version: VERSION)
        .order(created_at: :desc)
    end

    # Completed download whose file is still on disk; prefers newest original.
    def ready_for_query(term_query)
      existing_query = TermQuery.find_saved(term_query)
      return nil unless existing_query

      completed_originals_for_saved_query(existing_query).find(&:file_exists?)
    end

    def pending_for_query?(term_query)
      downloads_for_query(term_query)
        .where(status: :created)
        .where("created_at >= ?", EXPIRATION_TIME.ago)
        .exists?
    end

    def failed_for_query?(term_query)
      downloads_for_query(term_query)
        .where(status: :failed, expired_at: nil)
        .where("created_at >= ?", EXPIRATION_TIME.ago)
        .exists?
    end
  end

  # NOTE: for timing reasons, this does NOT #save the current model, you should do that yourself.
  def mark_as_failed(message, backtrace)
    self.transaction do
      self.status = :failed
      self.completed_at = Time.now # Yes, this is duplicated from #background_build, but it's safer to do so.
      build_download_error({message: message, backtrace: backtrace})
    end
  end

  def processing?
    self.processing_since.present?
  end

  def file_exists?
    return false if filename.blank?
    path = TraitBank::DataDownload.path.join(filename)
    File.exist?(path)
  end

  def delete_file
    if self.completed? && !self.filename.blank? && self.original?
      path = TraitBank::DataDownload.path.join(self.filename)
      begin
        File.delete(path)
      rescue => e
        Rails.logger.error("Failed to delete user download file #{path}", e)
      end
    end
  end

private
  def background_build
    begin
      Rails.logger.warn("Begin background build of #{count} rows for #{term_query} -> #{search_url}")
      self.update(processing_since: Time.current)
      downloader = TraitBank::DataDownload.new(term_query: term_query, count: count, search_url: search_url, user_id: User.first.id)
      self.filename = downloader.background_build
      self.status = :completed
    rescue => e
      Rails.logger.error("!! ERROR in background_build for User Download #{id}")
      Rails.logger.error("!! ERROR in background_build for User Download #{id}")
      Rails.logger.error("!! #{e.message}")
      Rails.logger.error("!! #{e.message}")
      Rails.logger.error("!! #{e.backtrace.join('->')}")
      Rails.logger.error("!! #{e.backtrace.join('->')}")
      mark_as_failed(e.message, e.backtrace.join("\n"))
      raise e
    ensure
      self.completed_at = Time.now
      save! # NOTE: this could fail and we lose everything.
      Rails.logger.warn("End background build of #{count} rows for #{term_query} -> #{search_url}")
    end
  end
  handle_asynchronously :background_build, :queue => "download"
end
