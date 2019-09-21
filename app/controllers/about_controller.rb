class AboutController < ApplicationController
  def trait_bank
    example_query = TermQuery.new(
      filters: [
        TermQueryFilter.new(pred_uri: "http://www.wikidata.org/entity/Q1053008")
      ],
      result_type: :taxa
    )
    @example_search_path = term_search_results_path(term_query: example_query.to_params)
    @autogen_page_path = page_path(id: 46559130)
  end
end
