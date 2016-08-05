# Abstraction between our traits and the implementation of the triple store. We
# could have called this "TripleStore," in fact.
class TraitBank
  class < self
    def connection
      @connection ||= 
    end

    def trait_exists?(uri)
      r = connection.query("SELECT COUNT(*) { <#{uri}> ?o ?p }")
      return false unless r.first && r.first.has_key?(:"callret-0")
      r.first[:"callret-0"].to_i > 0
    end
  end
end
