# This is basically a façade around an ImportLog.
class Publishing::PubLog
  attr_accessor :logger, :resource

  def initialize(resource = nil, options = {})
    @resource = resource
    @logger = @resource ? choose_logger(options[:use_existing_log]) : nil
  end

  def choose_logger(option)
    if @resource.import_logs.count.zero?
      log = @resource.create_log
      log.pause # We pause the new log so it doesn't block the check to see if anything is currently running.
      return log
    end

    last_log = @resource.import_logs.last
    return last_log if option
    return last_log if last_log.created_at > 15.minutes.ago
    return @resource.create_log
  end

  def start(what)
    @resource.import_logs.last&.running
    log(what.to_s, cat: :starts)
  end

  def pause
    @resource.import_logs.last&.pause
    log("...pausing for next background job...", cat: :ends)
  end

  def end(what)
    log(what.to_s, cat: :ends)
  end

  def warn(what)
    log(what.to_s, cat: :warns)
  end

  def info(what)
    log(what.to_s, cat: :infos)
  end

  def error(what)
    log(what.to_s, cat: :errors)
  end

  def log(what, type = nil)
    cat = type && type.key?(:cat) ? type[:cat] : :starts
    add_text_logs("(#{cat}) #{what}")
    @logger&.log(what, type)
  end

  def log_update(what)
    add_text_logs("(update) #{what}")
    @logger&.log_update(what)
  end

  def fail_on_error(e)
    add_text_logs("(errors) !! #{e.message}")
    count = 1
    root = Rails.root.to_s
    if e.backtrace
      e.backtrace.each do |trace|
        trace = trace.sub(root, '[root]').sub(%r{\A.*/gems/}, '[gems]/')
        add_text_logs("(errors) (trace) #{trace}")
        count += 1
      end
    end
    @logger&.fail_on_error(e)
  end

  def complete
    add_text_logs("(ends) completed resource #{@resource.name} (#{@resource.id})")
    # Making sure we call complete on the last working import log, regardless of what we're holding on to:
    @resource.import_logs.last&.complete
  end
  alias_method :close, :complete

  def add_text_logs(str)
    t = Time.now.strftime('%H:%M:%S')
    Rails.logger.info("PUB[#{t}] #{str}")
    puts("[#{t}] #{str}")
  end
end
