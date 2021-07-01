class BriefSummary
  class Builder
    class SentenceSpec
      VALID_TYPES = [:any_lang, :english]

      attr_reader :type, :method

      def initialize(type, method)
        raise TypeError, "invalid type: #{type}" unless VALID_TYPES.include?(type)

        @type = type
        @method = method
      end
    end

    def initialize(page, view, sentences, locale)
      @page = BriefSummary::PageDecorator.new(page, view)
      @view = view
      @sentences = sentences
      @locale = locale
      @tracker = TermTracker.new
      @tagger = TermTagger.new(@tracker, view)
      @helper = Sentences::Helper.new(@tagger, view)
    end

    def build
      BriefSummary.new(build_value, @tracker.result_terms)
    end

    def terms
      @tracker.result_terms
    end

    private
    def build_value
      values = []

      @sentences.each do |sentence|
        begin
          result = self.send(sentence.type).send(sentence.method)
          values << result.value if result.valid?
        rescue BriefSummary::BadTraitError => e
          Rails.logger.warn(e)
        end
      end

      values.join(' ')
    end

    def english
      @english ||= Sentences::English.new(@page, @helper)
    end

    def any_lang
      @any_lang ||= Sentences::AnyLang.new(@page, @helper, @locale)
    end
  end
end
