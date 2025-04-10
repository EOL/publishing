module TraitBank
  class Logger
    class << self
      LOGGER = Rails.application.config.neo4j.logger

      def log(message)
        # Disabling this because of overload
        # LOGGER.info(message)
      end

      def warn(message)
        # Disabling this because of overload
        # LOGGER.warn(message)
      end

      def log_error(message)
        LOGGER.error(message)
      end
    end
  end
end
