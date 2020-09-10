require "set"

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

    class SankeyNode
      attr_accessor :uri, :name

      def initialize(uri, name, page_ids)
        @uri = uri
        @name = name
        @page_ids = Set.new(page_ids)
      end

      def to_h
        {
          uri: uri,
          name: name, 
          fixedValue: @page_ids.size
        }
      end

      def add_page_ids(page_ids)
        @page_ids = @page_ids.union(page_ids)
      end
    end

    def sankey
      @query = TermQuery.new(term_query_params)
      results = TraitBank::Stats.sankey_data(@query)
      updated_results = update_query_term_chords_and_sort(results)
      node_limit_per_axis = 10

      # Result is chords ordered by size. Walk through chords, adding to results if
      # each of its nodes either
      # belongs to an axis that hasn't hit its node limit OR
      # already exists in its axis
      
      uris_per_axis = Array.new(@query.filters.length) { |_| Set.new }
      ok_results = []

      # filter results
      updated_results.each do |r|
        nodes_ok = true
        i = 0
        result_uris = []

        while i < @query.filters.length && nodes_ok
          uri_key = :"child#{i}_uri"
          uri = r[uri_key]

          if !(
            uris_per_axis[i].length < node_limit_per_axis ||
            uris_per_axis[i].include?(uri)
          )
            nodes_ok = false
          end

          result_uris << uri
          i += 1
        end

        if nodes_ok
          result_uris.each_with_index do |uri, i|
            uris_per_axis[i].add(uri)
          end

          ok_results << r
        end
      end

      nodes_by_uri = {}
      @links = []

      ok_results.each do |r|
        page_ids = r[:page_ids]

        prev_node = nil

        (0..@query.filters.length - 1).each do |i|
          uri_key = :"child#{i}_uri"
          name_key = :"child#{i}_name"
          uri = r[uri_key]
          name = r[name_key]
          
          if nodes_by_uri.include?(uri)
            nodes_by_uri[uri].add_page_ids(page_ids)
          else
            nodes_by_uri[uri] = SankeyNode.new(uri, name, page_ids)
          end

          cur_node = nodes_by_uri[uri]

          # add link
          if prev_node
            @links << { 
              source: prev_node.uri, 
              target: cur_node.uri, 
              value: page_ids.length, 
              names: [prev_node.name, cur_node.name] 
            }
          end
          prev_node = cur_node
        end
      end
        
      @nodes = nodes_by_uri.values.map { |n| n.to_h }
      @data = { nodes: @nodes, links: @links }
      render_with_status(@nodes.any? && @links.any?)
    end

    private
    def update_query_term_chords_and_sort(query_results)
      query_uris = Set.new(@query.filters.map { |f| f.obj_uri })
      query_term_results = []
      other_results = []
      other_page_ids = Set.new

      query_results.each do |r|
        query_term_result = false

        @query.filters.each_with_index do |_, i|
          uri_key = :"child#{i}_uri"
          name_key = :"child#{i}_name"
          uri = r[uri_key]

          if query_uris.include?(uri)
            r[name_key] = I18n.t("traits.data_viz.other_term_name", term_name: r[name_key])
            query_term_result = true
          end
        end

        if query_term_result
          query_term_results << r
        else
          other_results << r
          other_page_ids = other_page_ids.union(r[:page_ids])
        end
      end

      query_term_results.each do |r|
        page_ids = r[:page_ids]
        new_page_ids = []

        page_ids.each do |id|
          if !other_page_ids.include?(id)
            new_page_ids << id
          end
        end

        r[:page_ids] = new_page_ids
      end

      results = query_term_results + other_results
      results.sort { |a, b| b[:page_ids].length <=> a[:page_ids].length }
    end

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
