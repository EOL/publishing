module TraitBank
  class Logger
    class << self
      LOGGER = Rails.application.config.neo4j.logger
      def log(message, tag = nil)
        tag ||= 'INFO'
        time = Time.now
        LOGGER.tagged(tag) { LOGGER.warn("[#{time.strftime('%F %T')}] #{message}") }
      end

      def warn(message)
        log(message, 'WARN')
      end

      def log_error(message)
        log(message, 'ERR')
      end
    end
  end
end
