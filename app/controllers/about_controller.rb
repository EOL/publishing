class AboutController < ApplicationController
  TB_WORDCLOUD_FILE_PATH = Rails.root.join("data", "top_pred_counts.json")

  def trait_bank
    example_query = TermQuery.new(
      filters: [
        TermQueryFilter.new(pred_uri: "http://www.wikidata.org/entity/Q1053008")
      ],
      result_type: :taxa
    )
    @example_search_path = term_search_results_path(term_query: example_query.to_params)
    @autogen_page_path = page_path(id: 46559130)
    @wordcloud_data = AboutController.tb_wordcloud_data
  end

  def self.tb_wordcloud_data
    # links are different per locale
    if !@tb_wordcloud_data
      if File.exist?(TB_WORDCLOUD_FILE_PATH)
        @tb_wordcloud_data = JSON.parse(File.read(TB_WORDCLOUD_FILE_PATH))
      else
        logger.error("TraitBank wordcloud file doesn't exist: #{TB_WORDCLOUD_FILE_PATH}. Run `rails r scripts/top_pred_counts.rb` to generate.")
        return [] 
      end
    end

    @tb_wordcloud_data.collect do |datum|
      term_query = TermQuery.new(
        filters: [
          TermQueryFilter.new(pred_uri: datum["uri"])
        ],
        result_type: :record
      )

      {
        text: datum["name"],
        weight: Math.log(datum["count"], 2),
        link: Rails.application.routes.url_helpers.term_search_results_path(term_query: term_query.to_params)
      }
    end
  end
end
