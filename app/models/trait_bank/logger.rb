class TraitBank
  class Logger
    def logger
      @logger ||= ActiveSupport::TaggedLogging.new(Logger.new(Rails.root.join('log', 'traitbank.log')
    end

    def log(message, tag = nil)
      tag ||= 'INFO'
      time = Time.now
      delta = @last_time.nil? ? '' : "<#{(time - @last_time).round(3)}s>"
      logger.tagged(tag) { process_log.("[#{time.strftime('%F %T')}]#{delta} #{message}") }
      @last_time = time
    end

    def warn(message)
      log(message, 'WARN')
    end

    def log_error(message)
      log(message, 'ERR')
    end
  end
end
