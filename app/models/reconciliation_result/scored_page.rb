class ReconciliationResult
  class ScoredPage
    INEXACT_TOP_SCORE = 75
    MIN_NAME_SCORE = 50

    attr_accessor :page, :score, :confident_match

    def initialize(page, score, confident_match)
      @page = page
      @score = score
      @confident_match = confident_match
    end

    class << self
      def from_searchkick_results(query_string, searchkick_results)
        results = process_searchkick_results(searchkick_results)
        return [] if results.empty?

        best_match_result = results.first
        best_match = best_match_result.page
        highlight_strs = best_match.search_highlights.values.map { |v| v.downcase }
        best_score_abs = highlight_strs.include?(query_string.downcase) ? ReconciliationResult::MAX_SCORE : INEXACT_TOP_SCORE
        best_score_rel = best_match_result.score
        worst_score_rel = results.last.score
        rel_range = best_score_rel - worst_score_rel
        abs_range = best_score_abs - MIN_NAME_SCORE
        abs_rel_ratio = rel_range > 0 ? abs_range * 1.0 / rel_range : 0 # 0 is a sentinel value, won't be used in calculations

        results.map.with_index do |result, i|
          score_rel = result.score
          score_abs = abs_rel_ratio > 0 ? (score_rel - worst_score_rel) * abs_rel_ratio + MIN_NAME_SCORE : best_score_abs

          # First result is a confident match if 
          # 1) a search field matches the query exactly (best_score_abs == MAX_SCORE)
          # 2) the next result has a lower score (or doesn't exist)
          confident_match = (
            i == 0 && 
            (results.length == 1 || results.second.score < score_rel) &&
            best_score_abs == MAX_SCORE
          )

          self.new(result.page, score_abs, confident_match)
        end.compact
      end

      private
      InternalResult = Struct.new(:page, :score)

      def process_searchkick_results(searchkick_results)
        internal_results = []

        pages = searchkick_results.results
        hits = searchkick_results.hits

        pages.each_with_index do |page, i|
          if page
            internal_results << InternalResult.new(page, hits[i]['_score'])
          end
          # if elasticsearch is out of sync with the db (index out of date), page can be nil, and we should ignore such results
        end

        internal_results
      end
    end
  end
end
