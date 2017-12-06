class TraitBank
  class TermQuery
    class Sort 
      include ActiveModel::Model

      attr_accessor :dir
      attr_accessor :field
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

    include ActiveModel::Model

    NUM_PAIRS = 4
    PER_PAGE = 50
    # SORTS are not used at the moment
    SORTS = {
      :pred_asc => { 
        :name => "Predicate name (asc)",
        :sort => Sort.new(:dir => :asc, :field => :predicate)
      },
      :pred_desc => {
        :name => "Predicate name (desc)",
        :sort => Sort.new(:dir => :desc,  :field => :predicate)
      }
    }
    SORT_OPTIONS = SORTS.collect do |param, val|
      [val[:name], param]
    end

    attr_accessor :pairs
    attr_accessor :type
    attr_accessor :clade

    def initialize(*)
      super
      @clade = nil if @clade.blank?
      @type = "record" if @type.blank?
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
    
    def sort_options
      SORT_OPTIONS
    end

    def sort
      if @sort 
        SORTS.dig(@sort.to_sym, :sort)
      else
        nil
      end
    end

    def sort=(sort)
      @sort = sort
    end
  end
end
