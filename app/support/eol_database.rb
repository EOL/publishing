# Convenience methods for when we interact with the database.
module EolDatabase
  class << self
    def reconnect_if_idle
      tried = false
      yield
    rescue => e
      ActiveRecord::Base.connection.reconnect!
      raise e if tried
      tried = true
      retry
    end
  end
end
