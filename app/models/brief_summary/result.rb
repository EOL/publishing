class BriefSummary
  class Result
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
      @view = view
      @page = BriefSummary::PageDecorator.new(page, view)
      @tracker = TermTracker.new
      @tagger = TermTagger.new(@tracker, view)
      @helper = Sentences::Helper.new(@tagger, view)
      @locale = locale
      @string = build_string(sentences)
    end

    def value
      @string
    end

    def terms
      @tracker.result_terms
    end

    private
    def build_string(sentences)
      values = []

      sentences.each do |sentence|
        begin
          result = self.send(sentence.type).send(sentence.method)
          values << result.value if result.valid?
        rescue BadTraitError => e
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
