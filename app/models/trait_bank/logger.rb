class TraitBank
  class Logger
    class << self
      def log(message, tag = nil)
        tag ||= 'INFO'
        time = Time.now
        @logger ||= ActiveSupport::TaggedLogging.new(::Logger.new(Rails.root.join('log', 'traitbank.log')))
        @logger.tagged(tag) { @logger.warn("[#{time.strftime('%F %T')}] #{message}") }
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
