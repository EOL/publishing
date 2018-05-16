class Trait
  class << self
    # Checks for a data based on its resource and their PK for the data:
    def exists?(resource_id, pk)
      TraitBank.data_exists?(resource_id, pk)
    end

    def humanize_uri(uri)
      if matches = uri.match(/(\/|#)([a-z0-9,_-]{1,})$/i)
        matches[2]
      else
        uri.sub(/http:\/\//, "")
      end.underscore.gsub(/\W/, " ").titleize
    end
  end
end
