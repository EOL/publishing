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

      # TODO: update to use TermNode rather than TraitBank query methods
      def initialize(tb_result, query)
        cols = tb_result["columns"]
        data = tb_result["data"]
        i_bi = cols.index("bi")
        i_bw = cols.index("bw")
        i_count = cols.index("c")
        i_min = cols.index("min")
        units_uri = query.filters.first.units_term&.uri || TraitBank::Term.units_for_term(query.filters.first.predicate.uri)

        raise TypeError, 'failed to get a units term for query' if units_uri.nil?

        @units_term = TraitBank::Term.term_record(units_uri)

        @max_bi = data.last[i_bi].to_i
        @bw = self.class.to_d_or_i(data.first[i_bw])
        @min = self.class.to_d_or_i(data.first[i_min])

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

    class AssocData
      def initialize(query)
        result = TraitBank::Stats.assoc_data(query)
        page_ids = Set.new
        subj_page_id_map = {}
        obj_page_id_map = {}

        result.each do |row|
          subj_page_id = row[:subj_group_id]
          obj_page_id = row[:obj_group_id]
          page_ids.add(subj_page_id)
          page_ids.add(obj_page_id)
          subj_page_id_map[obj_page_id] ||= []
          subj_page_id_map[obj_page_id] << subj_page_id
          obj_page_id_map[subj_page_id] ||= []
          obj_page_id_map[subj_page_id] << obj_page_id
        end

        pages = Page.includes(native_node: { node_ancestors: { ancestor: :page }}).where(id: page_ids)
        page_ancestors = pages.map do |p|
          p.node_ancestors.map { |a| a.ancestor.page }.concat([p])
        end
        @root_node = build_page_hierarchy(page_ids, subj_page_id_map, obj_page_id_map, page_ancestors)

        pages_by_id = pages.map { |p| [p.id, p] }.to_h
        seen_pair_ids = Set.new
        @data = result.map do |row|
          subj_group = page_hash(row, :subj_group_id, pages_by_id)
          obj_group = page_hash(row, :obj_group_id, pages_by_id)

          pair_id = [subj_group[:page_id], obj_group[:page_id]].sort.join('_')

          next nil if seen_pair_ids.include?(pair_id) # arbitrarily drop one half of circular relationships

          seen_pair_ids.add(pair_id)
          
          {
            subjGroup: subj_group,
            objGroup: obj_group
          }
        end.compact
      end

      def to_json
        @root_node.to_h.to_json
      end

      private
      class Node
        attr_accessor :page, :children
        def initialize(page)
          @page = page
          @children = Set.new
          @subj_page_ids = Set.new
          @obj_page_ids = Set.new
        end

        def add_child(node)
          @children.add(node)
        end

        def has_child?(node)
          @children.include?(node)
        end

        def add_obj_page_ids(obj_page_ids)
          @obj_page_ids.merge(obj_page_ids)
        end

        def add_subj_page_ids(subj_page_ids)
          @subj_page_ids.merge(subj_page_ids)
        end

        def to_h
          children_h = @children.map { |c| c.to_h }

          {
            pageId: @page.id,
            name: @page.name,
            children: children_h,
            objPageIds: @obj_page_ids.to_a,
            subjPageIds: @subj_page_ids.to_a
          }
        end
      end

      def page_hash(row, key, pages)
        id = row[key]
        page = pages[id]

        {
          page_id: id,
          name: page.name
        }
      end

      def build_page_hierarchy(all_page_ids, subj_page_id_map, obj_page_id_map, page_ancestors)
        root_node = nil

        page_ancestors.each_with_index do |ancestry|
          page_root_node = Node.new(ancestry.first)
          cur_node = page_root_node

          ancestry[1..].each_with_index do |page, i|
            prev_node = cur_node
            cur_node = Node.new(page)

            if i == ancestry.length - 2 # leaf node is last element, - 2 because this is a slice starting at 1
              subj_page_ids = subj_page_id_map[page.id]
              obj_page_ids = obj_page_id_map[page.id]
              cur_node.add_obj_page_ids(obj_page_ids) if obj_page_ids
              cur_node.add_subj_page_ids(subj_page_ids) if subj_page_ids
            end

            prev_node.add_child(cur_node)
          end

          if !root_node
            root_node = page_root_node
            next
          end

          candidate_lca = root_node
          while candidate_lca.page == page_root_node.page && page_root_node.children.any?
            page_root_node = page_root_node.children.first # there's only one child
            if new_candidate_lca = candidate_lca.children.find { |c| c.page == page_root_node.page }
              candidate_lca = new_candidate_lca
            else
              candidate_lca.add_child(page_root_node)
              break
            end
          end
        end

        # We always end up with a hierarchy rooted at life, which may or may not be the actual lowest common ancestor for the pages in the result set. Walk down the tree until we get to the actual lca.
        while root_node.children.length == 1 && !all_page_ids.include?(root_node.page.id)
          root_node = root_node.children.first
        end

        root_node
      end
    end

    def bar
      @query = TermQuery.from_short_params(term_query_params)
      result = TraitBank::Stats.obj_counts(@query, BAR_CHART_LIMIT)
      @data = result.collect { |r| viz_result_from_row(@query, r) }
      render_common
    end

    def hist
      @query = TermQuery.from_short_params(term_query_params)
      counts = TraitBank::Search.term_search(@query, { count: true })
      result = TraitBank::Stats.histogram(@query, counts.primary_for_query(@query))
      @data = HistData.new(result, @query)
      render_common
    end

    def sankey
      @query = TermQuery.from_short_params(term_query_params)
      counts = TraitBank::Search.term_search(@query, { count: true })
      @sankey = Traits::DataViz::Sankey.create_from_query(@query, counts.primary_for_query(@query))
      set_sankey_about_text
      render_with_status(@sankey.multiple_paths?)
    end

    def assoc
      @query = TermQuery.from_short_params(term_query_params)
      @data = AssocData.new(@query)
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
            predicate_id: query.filters.first.predicate&.id,
            object_term_id: row[:obj][:eol_id] 
          }]
        }),
        row[:count],
        query.filters.first.object_term&.id == row[:obj][:eol_id]
      )
    end

    def term_query_params
      params.require(:tq).permit(TermQuery.expected_short_params)
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
