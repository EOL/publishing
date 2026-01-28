ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

module ActiveGraph
  module Migrations
    class << self
      def check_for_pending_migrations!
        return true
      end
    end
  end
end