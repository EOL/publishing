module Traits
  class DataVizController < ApplicationController
    BAR_CHART_LIMIT = 15

    ObjVizResult = Struct.new(:obj, :query, :count, :is_other) do
      class << self
        def other(count)
          self.new(nil, nil, count, true)
        end
      end

      def other?
        is_other
      end
    end

    class HistData
      class HistResult
        attr_reader :index, :count

        def initialize(raw_index, raw_count)
          @index = raw_index.to_i
          @count = raw_count.to_i
        end

        def to_h
          {
            index: index,
            count: count
          }
        end
      end

      def initialize(tb_result)
        cols = tb_result["columns"]
        data = tb_result["data"]
        i_bi = cols.index("bi")
        i_bw = cols.index("bw")
        i_count = cols.index("c")
        i_min = cols.index("min")

        @max_bi = data.last[i_bi].to_i
        @bw = data.first[i_bw].to_i
        @min = data.first[i_min].to_i
        @max_count = 0

        result_stack = data.collect do |d|
          @max_count = d[i_count] if d[i_count] > @max_count
          HistResult.new(d[i_bi], d[i_count])
        end.reverse
        
        cur_bucket = result_stack.pop

        @buckets = (0..@max_bi).collect do |i|
          if cur_bucket.index == i
            prev_bucket = cur_bucket
            cur_bucket = result_stack.pop
            prev_bucket
          else
            HistResult.new(i, 0)
          end
        end
      end

      def to_json
        {
          maxBi: @max_bi,
          bw: @bw,
          min: @min,
          maxCount: @max_count,
          buckets: @buckets.collect { |b| b.to_h }
        }.to_json
      end

      def length
        @buckets.length
      end
    end

    # unsupported
    def pie
      @query = TermQuery.new(term_query_params)
      result = TraitBank::Stats.obj_counts(@query)
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

      @data << ObjVizResult.other(other_count)
      render_common
    end

    def bar
      @query = TermQuery.new(term_query_params)
      counts = TraitBank.term_search(@query, { count: true })
      result = TraitBank::Stats.obj_counts(@query, counts.records, BAR_CHART_LIMIT)
      @data = result.collect { |r| viz_result_from_row(@query, r) }
      render_common
    end

    def hist
      query = TermQuery.new(term_query_params)
      counts = TraitBank.term_search(query, { count: true })
      result = TraitBank::Stats.histogram(query, counts.records)
      @data = HistData.new(result)
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
      ObjVizResult.new(
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
