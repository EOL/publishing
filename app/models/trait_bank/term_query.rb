class TraitBank
  class TermQuery
    class Pair
      include ActiveModel::Model

      def initialize(*)
        super
        @object = nil if @object.blank?
      end

      attr_accessor :predicate
      attr_accessor :object
    end

    include ActiveModel::Model

    NUM_PAIRS = 4
    PER_PAGE = 50

    attr_accessor :pairs
    attr_accessor :clade

    def initialize(*)
      super
      @clade = nil if @clade.blank?
    end

    def pairs_attributes=(attributes)
      @pairs ||= []
      attributes.each do |i, pair_params|
        @pairs.push(Pair.new(pair_params))
      end
    end

    def search_pairs
      @pairs.select do |pair|
        !pair.predicate.blank?
      end
    end

    def add_pair
      @pairs ||= []
      @pairs.push(Pair.new)
    end

    def remove_pair(index)
      @pairs.delete_at(index)
    end

    def clade_name
      if @clade
        @clade_name ||= Page.find(@clade)&.name
      else
        nil
      end
    end
  end
end
