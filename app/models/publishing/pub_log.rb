# This is basically a façade around an ImportLog.
class Publishing::PubLog
  attr_accessor :logger, :resource

  def initialize(resource = nil, options = {})
    @resource = resource
    use_last_log = use_existing_log(options[:use_existing_log])
    @logger = if @resource
      if use_last_log
        @resource.import_logs.last
      else
        @resource.create_log # This is an ImportLog.
      end
    else
      nil
    end
  end

  def use_existing_log(option)
    return true if option
    return false if @resource.import_logs.count.zero?
    return true if @resource.import_logs.last.created_at < 15.minutes.ago
    return false
  end

  def start(what)
    log(what.to_s, cat: :starts)
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

  def log(what, type = nil)
    cat = type && type.key?(:cat) ? type[:cat] : :starts
    add_text_logs("(#{cat}) #{what}")
    @logger&.log(what, type)
  end

  def fail_on_error(e)
    add_text_logs("(errors) !! #{e.message}")
    count = 1
    root = Rails.root.to_s
    if e.backtrace
      e.backtrace.each do |trace|
        trace = trace.sub(root, '[root]').sub(%r{\A.*/gems/}, '[gems]/')
        add_text_logs("(errors) (trace) #{trace}")
        if count >= 10
          more = e.backtrace.size - 10
          add_text_logs("(errors) (trace) SKIPPING #{more} MORE")
          break
        end
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
