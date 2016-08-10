class Trait
  class << self
    # Checks for a trait based on its "packet" URI:
    def exists?(uri)
      TraitBank.trait_exists?(uri)
    end
end
