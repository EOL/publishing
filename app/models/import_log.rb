class ImportLog < ApplicationRecord
  belongs_to :resource
  has_many :import_events, inverse_of: :import_log

  scope :successful, -> { where("completed_at IS NOT NULL") }
  scope :running, -> { where("completed_at IS NULL AND failed_at IS NULL") }

  PAUSE_STATUS = 'paused'
  LIMIT = 65_000

  class << self
    def all_clear!
      now = Time.now
      where(completed_at: nil, failed_at: nil).update_all(completed_at: now, failed_at: now)
      where(status: 'currently running').update_all(status: 'stopped')
      ImportRun.where(completed_at: nil).update_all(completed_at: now)
    end

    def already_running?
      undo = 'rake publish:clear if you are SURE these are in an acceptable state.'
      if ImportRun.where(completed_at: nil).any?
        return("A Publishing run appears to be active. #{undo}")
      end
      logging = ImportLog.where(completed_at: nil, failed_at: nil).where("status <> '#{PAUSE_STATUS}'").includes(:resource)
      if logging.any?
        info = "Currently publishing: "
        info += logging.map do |log|
          if log.resource
            info += "ImportLog##{log.id}: #{log.resource.name} (Resource##{log.resource_id})"
          else
            info += "ImportLog##{log.id}: Missing Resource##{log.resource_id})"
          end
        end.join(' ; ')
        return info
      end
      false
    end
  end

  def log(body, options = nil)
    options ||= {}
    cat = options[:cat] || :starts
    call_level = 0
    # Dense code that looks for the class and the line number and appends ",line" if the class is the same, otherwise ">class:line"
    call_stack = caller.map { |c| file_and_line(c) }.select { |c| c !~ /_log/ }[0..5].reverse.inject do |str, c|
      (k,l) = c.split(':')
      str =~ /\b#{k}[^>]+$/ ? "#{str},#{l}" : "#{str}>#{c}"
    end
    body = "#{body}\n\n#{call_stack}"
    chop_into_text_chunks(body).each do |chunk|
      import_events << ImportEvent.create(import_log: self, cat: cat, body: chunk)
      puts "IMPORT #{cat}: #{chunk}"
    end
  end

  def file_and_line(called)
    called.sub(%r{.*/}, '').sub(/:in .*$/, '').sub('.rb', '')
  end

  def log_update(body)
    body = body[0..LIMIT] if body.size > LIMIT
    options ||= {}
    last_event = ImportEvent.where(import_log: self).last
    if last_event.updates?
      last_event.body = body
      last_event.save
    else
      import_events << ImportEvent.create(import_log: self, cat: :updates, body: body)
    end
  end

  def chop_into_text_chunks(str)
    chunks = []
    while str.size > LIMIT
      chunks << str[0..LIMIT]
      str = str[LIMIT..-1]
    end
    chunks << str
    chunks
  end

  def running
    update_attribute(:completed_at, nil) unless completed_at.nil?
    update_attribute(:failed_at, nil) unless failed_at.nil?
    unless status == 'currently running'
      update_attribute(:status, 'currently running')
      resource.touch # Ensure that we see the resource as having changed
      log('Running', cat: :starts)
    end
  end

  def complete
    update_attribute(:completed_at, Time.now) unless destroyed?
    update_attribute(:status, 'completed') unless destroyed? || failed_at
    resource.touch # Ensure that we see the resource as having changed
    log('Complete', cat: :ends)
  end

  def fail(error)
    msg = error[0..250]
    log("Manual failure called, process must have died. (#{msg})", cat: :errors)
    update_attribute(:failed_at, Time.now)
    update_attribute(:status, msg)
  end

  def pause
    update_attribute(:status, PAUSE_STATUS)
  end

  def fail_on_error(e)
    if e.backtrace
      e.backtrace.reverse.each_with_index do |trace, i|
        break if trace =~ /\/bundler/ || trace =~ /bin\/rails/
        skip = false # `next` doesn't seem to work here for some reason (?)
        if i > 2
          skip = true if trace =~ /kernel_require\.rb/
        end
        unless skip
          trace.gsub!(/^.*\/gems\//, 'gem:') # Remove ruby version stuff...
          trace.gsub!(/^.*\/ruby\//, 'ruby:') # Remove ruby version stuff...
          trace.gsub!(/^.*\/publishing\//, './') # Remove website path..
          log(trace, cat: :errors)
        end
      end
    end
    fail(e.message.gsub(/#<(\w+):0x[0-9a-f]+>/, '\\1')) # I don't need the memory information for models
  end
end
