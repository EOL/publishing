class TraitBank
  class Query
    include ActiveModel::Model

    NUM_PAIRS = 4
    PER_PAGE = 50

    attr_accessor :pairs
    attr_accessor :type
    attr_accessor :clade

    def initialize(*)
      super
      @clade = nil if @clade.blank?
    end

    def pairs_attributes=(attributes)
      @pairs ||= []
      attributes.each do |i, pair_params|
        @pairs.push(Pair.new(pair_params)) if pair_params[:predicate] && !pair_params[:predicate].blank?
      end
    end

    def fill_out_pairs!
      @pairs ||= []
      @pairs.push(Pair.new) while @pairs.length < NUM_PAIRS
    end

    class Pair
      include ActiveModel::Model

      def initialize(*)
        super
        @object = nil if @object.blank?
      end

      attr_accessor :predicate
      attr_accessor :object
    end
  end
end
