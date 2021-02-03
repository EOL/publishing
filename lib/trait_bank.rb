# Abstraction between our traits and the implementation of their storage. ATM, we use neo4j. THE SCHEMA FOR TRAITS CAN
# BE FOUND IN db/neo4j_schema.md ...please read that file before attempting to understand this one. :D
module TraitBank
  class << self
    delegate :log, :warn, :log_error, to: TraitBank::Logger

    def ping
      begin
        connection.list_indexes
      rescue Excon::Error::Socket => e
        return false
      end
      true
    end

    def query(q, params={})
      start = Time.now
      response = nil
      q.sub(/\A\s+/, "")
      begin
        response = ActiveGraph::Base.query(q, params, wrap: false)
        stop = Time.now
      ensure
        q_to_log = q.size > 80 && q !~ /\n/ ? q.gsub(/ +([A-Z ]+)/, "\n\\1") : q
        log(">>TB TraitBank [activegraph] (#{stop ? stop - start : "F"}):\n#{q_to_log}")
      end

      return nil if response.nil?
      response_a = response.to_a # NOTE: you must call to_a since the raw response only allows for iterating through once

      # Map neo4j-ruby-driver response to neography-like response
      cols = response_a.first&.keys || []
      data = response_a.map do |row|
        cols.map do |col|
          col_data = row[col]
          if col_data.respond_to?(:properties)
            { 
              'data' => col_data.properties.stringify_keys,
              'metadata' => { 'id' => col_data.id }
            }
          else
            col_data
          end
        end
      end

      { 
        'columns' => cols.map { |c| c.to_s }, # hashrocket for string keys
        'data' => data
      }
    end

    #def connection
    #  @connection ||= Neography::Rest.new(Rails.configuration.traitbank_url)
    #end

    #def query(q, params={})
    #  start = Time.now
    #  results = nil
    #  q.sub(/\A\s+/, "")
    #  begin
    #    results = connection.execute_query(q, params)
    #    stop = Time.now
    #  rescue Excon::Error::Socket => e
    #    log_error("Connection refused on query: #{q}")
    #    sleep(0.1)
    #    results = connection.execute_query(q, params)
    #  rescue Excon::Error::Timeout => e
    #    log_error("Timed out on query: #{q}")
    #    sleep(1)
    #    results = connection.execute_query(q, params)
    #  ensure
    #    q_to_log = q.size > 80 && q !~ /\n/ ? q.gsub(/ +([A-Z ]+)/, "\n\\1") : q
    #    log(">>TB TraitBank [neography] (#{stop ? stop - start : "F"}):\n#{q}")
    #  end
    #  results
    #end
  end
end
