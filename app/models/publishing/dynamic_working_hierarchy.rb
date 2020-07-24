class Publishing
  class DynamicWorkingHierarchy
    class << self
      def update(resource = nil, log = nil)
        resource ||= Resource.native
        log ||= Publishing::PubLog.new(resource, use_existing_log: true)
        obj = Publishing::DynamicWorkingHierarchy.new(resource, log)
        obj.update
      end
    end

    def initialize(resource, log)
      @resource = resource
      @log = log
    end

    def update
      begin
        @log.start('#update')
        run_all_steps_with_logging
      rescue => e
        @log.fail_on_error(e)
      ensure
        @log.end('#update')
        @log.close
      end
    end

    def run_all_steps_with_logging
      # There are many, many other things I think we want to do here, but let's start with this.
      @log.start('#fix_all_missing_native_nodes (note this has its own log file)')
      Page.fix_all_missing_native_nodes
      @log.start('Page::DescInfo.refresh')
      Page::DescInfo.refresh
    end
  end
end
