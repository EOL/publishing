class TraitBank
  class Query
    include ActiveModel::Model

    def initialize(attributes={})
      super
      @pairs = []

      2.times { @pairs << Pair.new }
    end

    def pairs 
      @pairs
    end

    def pairs_attributes=(attributes)
      pairs << Pair.new(attributes) 
    end

    class Pair
      include ActiveModel::Model

      attr_accessor :predicate
      attr_accessor :trait
    end
  end
end
