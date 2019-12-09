# Simple logging object.
class TraitBank::Terms::FetchLog
  def self.log_path
    Rails.root.join('log', 'terms_fetch.log')
  end

  def initialize()
    @log = ActiveSupport::TaggedLogging.new(Logger.new(TraitBank::Terms::FetchLog.log_path))
  end

  def <<(message)
    @log.warn("[#{Time.now.strftime('%F %T')}] #{message}")
  end
end
