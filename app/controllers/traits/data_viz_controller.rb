module Traits
  class DataVizController < ApplicationController
    def object_pie_chart
      query = TermQuery.new(term_query_params)
      @data = TraitBank::Stats.term_query_object_counts(query)
      @data.collect! do |result|
        result[:term_query] = TermQuery.new({
          filters_attributes: [{
              pred_uri: query.filters.first.pred_uri,
              obj_uri: result.dig(:obj, :uri)
          }],
          clade: query.clade
        })

        result
      end  
    end

    private
    def term_query_params
      # TODO: copied from TraitsController -- dry up
      params.require(:term_query).permit([
        :clade_id,
        :result_type,
        :filters_attributes => [
          :pred_uri,
          :top_pred_uri,
          :obj_uri,
          :op,
          :num_val1,
          :num_val2,
          :units_uri,
          :sex_uri,
          :lifestage_uri,
          :statistical_method_uri,
          :resource_id,
          :show_extra_fields,
          :pred_term_selects_attributes => [
            :type,
            :parent_uri,
            :selected_uri
          ],
          :obj_term_selects_attributes => [
            :type,
            :parent_uri,
            :selected_uri
          ]
        ]
      ])
    end
  end
end
