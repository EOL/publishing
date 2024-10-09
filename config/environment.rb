# Load the Rails application.
require_relative 'application'

# For whatever reason, this defaults to within the GEM directory, e.g.:
# "/gems/ruby/3.3.0/gems/activegraph-10.1.1/config/neo4j/config.yml"
# ...which is no good for us, so we set it here:
ActiveGraph::Config.default_file = "/app/config/neo4j/config.yml"
# When that's set, apparently this never gets set, soooo:
module ActiveGraph
  module Migrations
    class << self
      def currently_running_migrations
        return true # If it's NOT true, it's going to validate them, EVEN THOUGH WE CONFIGED IT NOT TO.
      end
    end
  end
end

# Initialize the Rails application.
Rails.application.initialize!