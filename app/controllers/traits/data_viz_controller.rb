require "set"

module Traits
  class DataVizController < ApplicationController
    before_action :set_1d_about_text, only: [:bar, :hist]

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

        @max_bi = data.last[i_bi].to_i
        @bw = self.class.to_d_or_i(data.first[i_bw])
        @min = self.class.to_d_or_i(data.first[i_min])
        @units_term = TraitBank.term_record(query.filters.first.units_uri)
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
            Bucket.new(i, 0, @bw, @min, query, @units_term[:uri])
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
      result = TraitBank::Stats.obj_counts(@query, BAR_CHART_LIMIT)
      @data = result.collect { |r| viz_result_from_row(@query, r) }
      render_common
    end

    def hist
      @query = TermQuery.new(term_query_params)
      counts = TraitBank.term_search(@query, { count: true })
      result = TraitBank::Stats.histogram(@query, counts.primary_for_query(@query))
      @data = HistData.new(result, @query)
      render_common
    end

    def sankey
      @query = TermQuery.new(term_query_params)
      counts = TraitBank.term_search(@query, { count: true })
      @sankey = Traits::DataViz::Sankey.create_from_query(@query, counts.primary_for_query(@query))
      set_sankey_about_text
      render_with_status(@sankey.multiple_paths?)
    end

    private
    def render_common
      render_with_status(@data.length > 1)
    end

    def render_with_status(any_data)
      status = any_data ? :ok : :no_content
      options = { status: status }
      render options
    end
      
    def viz_result_from_row(query, row)
      ObjVizResult.new(
        row[:obj],
        TermQuery.new({
          clade_id: query.clade_id,
          result_type: query.result_type,
          filters_attributes: [{
            predicate_id: query.filters.first.predicate.id,
            object_term_id: row[:obj][:eol_id] 
          }]
        }),
        row[:count],
        query.filters.first.object_term&.id == row[:obj][:eol_id]
      )
    end

    def term_query_params
      params.require(:term_query).permit(TermQuery.expected_params)
    end

    def set_1d_about_text
      @about_text_key = "about_this_chart_tooltip_1d"
    end

    def set_sankey_about_text
      @about_text_key = if @query.filters.length > 2
        "about_this_chart_tooltip_sankey_3+" 
      else
        "about_this_chart_tooltip_sankey_2d"
      end
    end
  end
end
