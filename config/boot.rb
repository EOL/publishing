ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

begin
  require 'active_graph'
rescue
  puts "ERROR: Neo4j/active_graph failed to connect! (#{e.class} - #{e.message})"
end

begin
  require 'neo4j_ruby_driver'
  # Nesting this b/c the error type doesn't exist until the module is required!
  begin 
    ActiveGraph::Migrations.check_for_pending_migrations!
  rescue Neo4j::Driver::Exceptions::SessionExpiredException => e
    puts "ERROR: Neo4j migrations pending! (#{e.class} - #{e.message})"
  end
rescue
  puts "ERROR: Neo4j/neo4j-ruby-driver failed to connect! (#{e.class} - #{e.message})"
end