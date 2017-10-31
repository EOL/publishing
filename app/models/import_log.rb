class ImportLog < ActiveRecord::Base
  belongs_to :resource
  has_many :import_events, inverse_of: :import_log

  scope :successful, -> { where("completed_at IS NOT NULL") }

  def log(body, options = nil)
    options ||= {}
    cat = options[:cat] || :starts
    chop_into_text_chunks(body).each do |chunk|
      import_events << ImportEvent.create(import_log: self, cat: cat, body: chunk)
      puts "[#{Time.now.strftime('%H:%M:%S')}] (#{cat}) #{chunk}"
    end
  end

  def chop_into_text_chunks(str)
    chunks = []
    while str.size > 65_500
      chunks << str[0..65_500]
      str = str[65_500..-1]
    end
    chunks << str
    chunks
  end

  def complete
    update_attribute(:completed_at, Time.now)
    update_attribute(:status, "completed")
  end

  def fail(e)
    log(e.message, cat: :errors)
    e.backtrace.each do |trace|
      log(trace.gsub(/^.*2\.4\.0/, '..'), cat: :errors)
    end
    update_attribute(:failed_at, Time.now)
    update_attribute(:status, e.message)
  end
end
