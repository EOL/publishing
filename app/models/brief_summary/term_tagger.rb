class BriefSummary
  class TermTagger
    def initialize(term_tracker, view)
      @tracker = term_tracker
      @view = view
    end

    def tag(label, predicate, term, source)
      raise TypeError, "label can't be blank" if label.blank?

      @view.content_tag(
        :span,
        label,
        class: ['a', 'term-info-a'],
        id: @tracker.toggle_id(predicate, term, source)
      )
    end
  end
end
