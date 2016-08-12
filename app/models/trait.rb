class Trait
  class << self
    # Checks for a trait based on its resource and their PK for the trait:
    def exists?(resource_id, pk)
      TraitBank.trait_exists?(resource_id, pk)
    end
  end
end
