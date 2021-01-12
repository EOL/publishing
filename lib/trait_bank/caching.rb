module TraitBank
  module Caching
    class << self
      def add_hash_to_key(key, hash)
        hash.each do |k, v|
          key.concat("/#{k}_#{v}")
        end
      end
    end
  end
end
