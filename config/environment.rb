# Load the Rails application.
require_relative 'application'

# For whatever reason, this defaults to within the GEM directory, e.g.:
# "/gems/ruby/3.3.0/gems/activegraph-10.1.1/config/neo4j/config.yml"
# ...which is no good for us, so we set it here:
ActiveGraph::Config.default_file = "/app/config/neo4j/config.yml"

# Initialize the Rails application.
Rails.application.initialize!