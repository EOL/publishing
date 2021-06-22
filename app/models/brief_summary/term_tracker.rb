# Adds term tags to sentence/fragments and builds/holds the associated ResultTerms
class BriefSummary
  class TermTracker
    ResultTerm = Struct.new(:predicate, :term, :source, :toggle_selector)
    attr_reader :result_terms

    def initialize
      @toggle_id = -1 
      @result_terms = []
    end

    def toggle_id(predicate, term, trait_source)
      raise TypeError, "term can't be nil" if term.nil?

      selector = next_toggle_id
      @result_terms << ResultTerm.new(predicate, term, trait_source, selector)

      selector
    end

    private
    def next_toggle_id
      @toggle_id += 1
      "brief-summary-toggle-#{@toggle_id}"
    end
  end
end
