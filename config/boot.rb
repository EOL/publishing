ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

begin
  require 'activegraph'
rescue
  puts "ERROR: Neo4j/activestorage failed to connect! (#{e.class} - #{e.message})"
end

# TEMP! ...when you change activegraph or update gems, remove this, it's a security bump.
begin
  require 'activestorage'
rescue
  puts "ERROR: Neo4j/activestorage failed to connect! (#{e.class} - #{e.message})"
end

begin
  require 'neo4j-ruby-driver'
rescue
  puts "ERROR: Neo4j/neo4j-ruby-driver failed to connect! (#{e.class} - #{e.message})"
end