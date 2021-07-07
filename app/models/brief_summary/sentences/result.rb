class BriefSummary
  module Sentences
    class Result
      def initialize(valid, sentence)
        @valid = valid
        @sentence = sentence
      end

      def valid?
        @valid
      end

      def value
        raise TypeError, "not valid?" unless valid?
        @sentence
      end

      class << self
        private :new

        def valid(sentence)
          new(true, sentence)
        end

        def invalid
          new(false, nil)
        end
      end
    end
  end
end

