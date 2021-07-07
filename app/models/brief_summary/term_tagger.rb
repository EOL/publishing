class BriefSummary
  class TermTagger
    TAG_CLASSES = ['a', 'term-info-a']

    def initialize(term_tracker, view)
      @tracker = term_tracker
      @view = view
    end

    class << self
      def tag_class_str
        TAG_CLASSES.join(' ')
      end
    end

    def tag(label, predicate, term, source)
      raise TypeError, "label can't be blank" if label.blank?

      @view.content_tag(
        :span,
        label,
        class: TAG_CLASSES,
        id: @tracker.toggle_id(predicate, term, source)
      )
    end

    def toggle_id(predicate, term, source)
      @tracker.toggle_id(predicate, term, source)
    end
  end
end
