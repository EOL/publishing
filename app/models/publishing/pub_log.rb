# This is basically a façade around an ImportLog.
class Publishing::PubLog
  attr_accessor :logger, :resource

  # TODO: I would actually like to store publishing logs somewhere other than just in STDOUT.
  def initialize(resource = nil)
    @resource = resource
    @logger = @resource&.create_log # This is an ImportLog.
  end

  def log(what, type = nil)
    cat = type && type.key?(:cat) ? type[:cat] : :starts
    add_text_logs("(#{cat}) #{what}")
    @logger&.log(what, type)
  end

  def fail(e)
    add_text_logs("(errors) !! #{e.message}")
    @logger&.fail(e)
  end

  def complete
    add_text_logs("(ends) completed resource #{@resource}")
    @logger&.complete
  end

  def add_text_logs(str)
    t = Time.now.strftime('%H:%M:%S')
    Rails.logger.info("PUB[#{t}] #{str}")
    puts("[#{t}] #{str}")
  end
end
