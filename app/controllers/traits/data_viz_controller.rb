module Traits
  class DataVizController < ApplicationController
    layout "traits/data_viz"

    BAR_CHART_LIMIT = 15

    ObjVizResult = Struct.new(:obj, :query, :count, :noclick) do
      def noclick?
        noclick
      end
    end

    class HistData
      attr_reader :buckets, :max_bi, :bw, :min, :max_count, :units_term

      class Bucket
        attr_reader :index, :min, :limit, :count, :query, :buckets

        def initialize(raw_index, raw_count, bw, min, query, units_uri)
          @index = raw_index.to_i
          @min = min + bw * @index
          @limit = @min + bw # limit rather than max, since no value in the bucket ever reaches this limit -- it's an asymptote
          @count = raw_count.to_i

          @query = query.deep_dup
          qf = @query.filters.first
          qf.num_val1 = @min
          qf.num_val2 = @limit
          qf.units_uri = units_uri
        end

        def to_h
          {
            min: min,
            limit: limit,
            count: count
          }
        end
      end

      def initialize(tb_result, query)
        cols = tb_result["columns"]
        data = tb_result["data"]
        i_bi = cols.index("bi")
        i_bw = cols.index("bw")
        i_count = cols.index("c")
        i_min = cols.index("min")
        i_units = cols.index("u")

        @max_bi = data.last[i_bi].to_i
        @bw = self.class.to_d_or_i(data.first[i_bw])
        @min = self.class.to_d_or_i(data.first[i_min])
        @units_term = data.first[i_units]&.[]("data")&.symbolize_keys
        @max_count = 0

        result_stack = data.collect do |d|
          @max_count = d[i_count] if d[i_count] > @max_count
          Bucket.new(d[i_bi], d[i_count], @bw, @min, query, @units_term[:uri])
        end.reverse
        
        cur_bucket = result_stack.pop

        @buckets = (0..@max_bi).collect do |i|
          if cur_bucket.index == i
            prev_bucket = cur_bucket
            cur_bucket = result_stack.pop
            prev_bucket
          else
            Bucket.new(i, 0, @bw, @min, query)
          end
        end
      end

      def length
        @buckets.length
      end

      class << self
        def to_d_or_i(str_val)
          d = str_val.to_d
          (d % 1).zero? ? d.to_i : d
        end
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
      @query = TermQuery.new(term_query_params)
      counts = TraitBank.term_search(@query, { count: true })
      result = TraitBank::Stats.histogram(@query, counts.records)
      @data = HistData.new(result, @query)
      render_common
    end

    private
    def render_common
      status = @data.length > 1 ? :ok : :no_content
      options = { status: status }
      #options[:layout] = false if request.xhr?
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
        query.filters.first.obj_uri == row[:obj][:uri]
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
