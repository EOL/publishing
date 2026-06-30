ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Ruby 3.3+ no longer auto-loads `logger` (it moved from a default to a bundled
# gem), but ActiveSupport 6.1 references the `Logger` constant at load time
# before requiring it. Load it here, before any Rails framework, to avoid an
# "uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger" crash.
# REMOVE THIS WHEN YOU UPDATE TO RAILS 7.
require 'logger'

module ActiveGraph
  module Migrations
    class << self
      def check_for_pending_migrations!
        return true
      end
    end
  end
end
