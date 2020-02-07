module Traits
  class DataVizController < ApplicationController
    PieResult = Struct.new(:obj, :page, :query, :count, :is_other) do
      class << self
        def other(count)
          self.new(nil, nil, nil, count, true)
        end
      end

      def other?
        is_other
      end
    end

    def object_pie_chart
      @query = TermQuery.new(term_query_params)
      result = @query.record? ? TraitBank::Stats.term_query_object_counts(@query) : TraitBank::Stats.term_query_page_counts(@query)
      total = TraitBank.term_search(@query, count: true)
      min_threshold = 0.05 * total
      other_count = 0
      @data = []

      pages_by_id = {}
      if @query.taxa?
        pages = Page.with_name.where(id: result.collect { |r| r[:page][:page_id] })
        pages_by_id = pages.collect { |p| [p.id, p] }.to_h
      end  

      result.each do |row|
        if result.length > 20 && row[:count] < min_threshold
          other_count += row[:count]
        else
          @data << PieResult.new(
            @query.record? ? row[:obj] : nil,
            @query.taxa? ? pages_by_id[row[:page][:page_id]] : nil,
            build_tq_for_result(row, @query),
            row[:count],
            false
          )
        end
      end

      @data << PieResult.other(other_count)
      status = @data.length > 1 ? :ok : :no_content
      options = { status: status }
      options[:layout] = false if request.xhr?
      render options
    end

    private
    def build_tq_for_result(row, query)
      tq_attributes = { result_type: query.result_type }
      tq_attributes[:clade_id] = row[:page_id] if query.taxa?

      filter_attributes = {
        pred_uri: query.filters.first.pred_uri
      }
      filter_attributes[:obj_uri] = row[:obj][:uri] if query.record?

      tq_attributes[:filters_attributes] = [filter_attributes]
      TermQuery.new(tq_attributes)
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
