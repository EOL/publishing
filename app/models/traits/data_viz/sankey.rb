require "set"

# represents Sankey chart shown on certain trait search result pages
class Traits::DataViz::Sankey
  MAX_NODES_PER_AXIS = 10

  attr_reader :nodes, :links

  class << self
    def create_from_query(query, total_taxa)
      results = TraitBank::Stats.sankey_data(query)
      self.new(results, query, total_taxa)
    end
  end

  def multiple_paths?
    @links.length >= @num_axes 
  end

  private
  def initialize(query_results, query, total_taxa)
    @query = query
    @num_axes = query.filters.length
    @total_taxa = total_taxa

    query_uris = Set.new(query.filters.map { |f| f.obj_uri })
    result_rows = query_results.map { |r| ResultRow.new(r, query, query_uris) }
    nodes_by_axis = build_nodes_by_axis(result_rows)
    @nodes = nodes_by_axis.flatten
    other_nodes = update_results(result_rows, nodes_by_axis)
    @nodes.concat(other_nodes)
    fix_qt_row_page_ids(result_rows, nodes_by_axis)
    @links = build_links(result_rows)
  end

  def build_nodes_by_axis(rows)
    distinct_nodes_by_axis = Array.new(@num_axes) { {} }

    rows.each do |r|
      r.nodes.each_with_index do |n, i|
        next if n.query_term? # skip these for now -- they're added (and modified) at a later step

        existing = distinct_nodes_by_axis[i][n]

        if existing
          existing.merge(n)
        else
          distinct_nodes_by_axis[i][n] = n
        end
      end
    end

    distinct_nodes_by_axis.map do |nodes|
      nodes.values.sort { |a, b| b.size <=> a.size }[0..MAX_NODES_PER_AXIS]
    end
  end

  def update_results(results, nodes_by_axis)
    other_nodes_per_axis = Array.new(@num_axes, nil)

    results.each do |r|
      r.nodes = r.nodes.map.with_index do |n, i|
        matching_node = nodes_by_axis[i].find { |m| m == n }

        if matching_node
          matching_node
        else
          other_node = Node.new(
            @query.page_count_sorted_filters[i].obj_uri,
            i,
            r.page_ids, 
            true,
            @query
          )

          if other_nodes_per_axis[i]
            other_nodes_per_axis[i].merge(other_node)
          else
            other_nodes_per_axis[i] = other_node
          end

          other_nodes_per_axis[i]
        end
      end
    end

    other_nodes_per_axis.compact
  end

  def fix_qt_row_page_ids(results, nodes_per_axis)
    page_ids_per_axis = build_page_ids_per_axis(nodes_per_axis)

    results.each do |r|
      qt_nodes = r.query_term_nodes
      
      page_ids_to_remove = Set.new

      qt_nodes.each do |n|
        page_ids_to_remove.merge(page_ids_per_axis[n.axis_id])
        n.remove_page_ids(page_ids_per_axis[n.axis_id])
      end

      r.remove_page_ids(page_ids_to_remove)
    end
  end

  def build_page_ids_per_axis(nodes_per_axis)
    nodes_per_axis.map do |nodes|
      page_ids = Set.new

      nodes.each do |node|
        page_ids.merge(node.page_ids)
      end

      page_ids
    end
  end

  def build_links(results)
    links = {}

    results.each do |r|
      prev_node = nil

      r.nodes.each do |n|
        if prev_node
          link = Link.new(
            prev_node, 
            n, 
            r.page_ids
          )

          existing_link = links[link]

          if existing_link
            existing_link.merge(link)
          else
            links[link] = link
          end
        end

        prev_node = n
      end
    end

    links.values
  end

  class ResultRow
    attr_reader :page_ids
    attr_accessor :nodes

    def initialize(row, query, query_uris)
      @page_ids = Set.new(row[:page_ids])

      @nodes = query.page_count_sorted_filters.map.with_index do |_, i|
        uri_key = :"child#{i}_uri"
        uri = row[uri_key]
        node_query = query.deep_dup
        node_query.page_count_sorted_filters[i].obj_uri = uri 

        Node.new(
          uri,
          i,
          @page_ids,
          query_uris.include?(uri),
          node_query
        )
      end
    end

    def size
      @page_ids.size
    end

    def empty?
      @page_ids.empty?
    end

    def any_query_terms?
      !!(@nodes.find { |n| n.query_term? })
    end

    def query_term_nodes
      @nodes.filter { |n| n.query_term? }
    end

    def remove_page_ids(to_remove)
      @page_ids.subtract(to_remove)
    end
  end

  class Node
    attr_reader :uri, :axis_id, :page_ids, :query

    def initialize(uri, axis_id, page_ids, is_query_term, query)
      @uri = uri
      @axis_id = axis_id
      @is_query_term = is_query_term
      @query = query
      @page_ids = Set.new(page_ids)
    end

    def merge(other)
      @page_ids.merge(other.page_ids)
    end

    def query_term?
      @is_query_term
    end

    def size
      @page_ids.length
    end

    def add_page_ids(other)
      @page_ids.merge(other)
    end

    def remove_page_ids(other)
      @page_ids.subtract(other)
    end

    def id
      "#{@uri}-#{@axis_id}"
    end

    def ==(other)
      self.class === other and
        other.uri == @uri and
        other.axis_id == @axis_id
    end

    alias eql? ==

    def hash
      @uri.hash ^ @axis_id.hash
    end
  end

  class Link
    attr_reader :source, :target, :page_ids

    def initialize(source, target, page_ids)
      @source = source
      @target = target
      @page_ids = Set.new(page_ids)
    end

    def merge(other)
      @page_ids.merge(other.page_ids)
    end

    def add_page_ids(new_page_ids)
      @page_ids.merge(new_page_ids)
    end

    def size
      @page_ids.size
    end

    # page ids are not considered for equality/hash due to how this class is used
    def ==(other)
      self.class === other and
        other.source == @source and
        other.target == @target
    end

    alias eql? ==

    def hash
      @source.hash ^ @target.hash
    end
  end
end
