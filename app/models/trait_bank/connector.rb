module TraitBank::Connector
  class << self
    delegate :log, :warn, :log_error, to: TraitBank::Logger

    def connection
      @connection ||= Neography::Rest.new(Rails.configuration.traitbank_url)
    end

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
      results = nil
      q.sub(/\A\s+/, "")
      begin
        results = connection.execute_query(q, params)
        stop = Time.now
      rescue Excon::Error::Socket => e
        log_error("Connection refused on query: #{q}")
        sleep(0.1)
        results = connection.execute_query(q, params)
      rescue Excon::Error::Timeout => e
        log_error("Timed out on query: #{q}")
        sleep(1)
        results = connection.execute_query(q, params)
      ensure
        q_to_log = q.size > 80 && q !~ /\n/ ? q.gsub(/ +([A-Z ]+)/, "\n\\1") : q
        log(">>TB TraitBank [neography] (#{stop ? stop - start : "F"}):\n#{q}")
      end
      results
    end
  end
end
