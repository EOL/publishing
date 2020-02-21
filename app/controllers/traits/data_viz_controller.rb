module Traits
  class DataVizController < ApplicationController
    BAR_CHART_LIMIT = 15

    VizResult = Struct.new(:obj, :query, :count, :is_other) do
      class << self
        def other(count)
          self.new(nil, nil, count, true)
        end
      end

      def other?
        is_other
      end
    end

    def object_pie_chart
      @query = TermQuery.new(term_query_params)
      result = TraitBank::Stats.term_query_object_counts(@query)
      counts = TraitBank.term_search(@query, count: true)
      total = counts.primary_for_query(@query)
      min_threshold = 0.05 * total
      other_count = 0
      @data = []

      result.each do |row|
        if result.length > 20 && row[:count] < min_threshold
          other_count += row[:count]
        else
          @data << viz_result_from_row(@query, row)
        end
      end

      @data << VizResult.other(other_count)
      render_common
    end

    def taxon_bar_chart
      @query = TermQuery.new(term_query_params)
      result = TraitBank::Stats.term_query_taxon_counts(@query)
      top_results = result[0..BAR_CHART_LIMIT]
      @data = top_results.collect { |r| viz_result_from_row(@query, r) }
      render_common
    end

    private
    def render_common
      status = @data.length > 1 ? :ok : :no_content
      options = { status: status }
      options[:layout] = false if request.xhr?
      render options
    end
      
    def viz_result_from_row(query, row)
      VizResult.new(
        row[:obj],
        TermQuery.new({
          clade_id: query.clade_id,
          result_type: query.result_type,
          filters_attributes: [{
            pred_uri: query.filters.first.pred_uri,
            obj_uri: row[:obj][:uri] 
          }]
        }),
        row[:count],
        false
      )
    end

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
