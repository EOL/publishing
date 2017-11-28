class TraitBank
  class Query
    include ActiveModel::Model

    attr_accessor :pairs

    def pairs_attributes=(attributes)
      @pairs ||= []

      attributes.each do |i, pair_params|
        @pairs.push(Pair.new(pair_params)) if pair_params[:predicate] && !pair_params[:predicate].blank?
      end
    end

    class Pair
      include ActiveModel::Model

      attr_accessor :predicate
      attr_accessor :object
    end
  end
end
