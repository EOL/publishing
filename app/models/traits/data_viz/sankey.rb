require "set"

# represents Sankey chart shown on certain trait search result pages
class Traits::DataViz::Sankey
  MAX_NODES_PER_AXIS = 10

  attr_reader :nodes, :links

  class << self
    def create_from_query(query)
      results = TraitBank::Stats.sankey_data(query)
      self.new(results, query)
    end
  end

  private
  def initialize(query_results, query)
    qt_results = []
    other_results = []
    query_uris = Set.new(query.filters.map { |f| f.obj_uri })

    query_results.each do |r|
      result_row = ResultRow.new(r, query, query_uris)

      if result_row.any_query_terms?
        qt_results << result_row
      else
        other_results << result_row
      end
    end

    results = merge_and_sort_results(qt_results, other_results)
    build_nodes_and_links(results, query)
  end

  def merge_and_sort_results(qt_results, other_results)
    fix_qt_result_page_ids(qt_results, other_results)
    results = qt_results + other_results
    results.sort! { |a, b| b.size <=> a.size }.reject! { |r| r.empty? }
    results
  end

  def fix_qt_result_page_ids(qt_results, other_results)
    other_page_ids = Set.new
    other_results.each do |r| 
      other_page_ids.merge(r.page_ids)
      r.add_page_ids_to_nodes
    end

    qt_results.each do |r|
      r.remove_page_ids(other_page_ids) 
      r.add_page_ids_to_nodes
    end
  end

  def build_nodes_and_links(results, query)
    # used to keep track of a single 'canonical' link per pair of nodes (see comment about equality/hash in Link)
    links = Hash.new 
    nodes_per_axis = Array.new(query.filters.length) { |_| Hash.new } # same here, except per-axis

    results.each do |r|
      prev_node = false
      result_links = Array.new(r.nodes.length - 1)
      result_nodes = Array.new(r.nodes.length)
      add_result = true
      i = 0

      while add_result && i < r.nodes.length
        node = r.nodes[i]
        add_result = nodes_per_axis[i].include?(node) || nodes_per_axis[i].length < MAX_NODES_PER_AXIS
 
        if add_result
          result_nodes[i] = node
          result_links[i - 1] = Link.new(prev_node, node, r.page_ids) if prev_node
        end

        prev_node = node
        i += 1
      end

      add_nodes_and_links(result_nodes, result_links, nodes_per_axis, links) if add_result
    end

    @nodes = nodes_per_axis.map { |node_hash| node_hash.values }.flatten
    @links = links.values
  end

  def add_nodes_and_links(result_nodes, result_links, nodes_per_axis, links)
    result_nodes.each_with_index do |node, i|
      merge_or_add_node(node, nodes_per_axis, i)
    end

    result_links.each do |link|
      merge_or_add_link(link, links)
    end
  end

  def merge_or_add_node(node, nodes_per_axis, axis_id)
    existing_node = nodes_per_axis[axis_id][node]

    if existing_node
      merge(existing_node, node)
    else
      nodes_per_axis[axis_id][node] = node
    end
  end

  def merge_or_add_link(link, links)
    existing = links[link]

    if existing
      merge(existing, link)
    else
      links[link] = link
    end
  end

  def merge(canonical, other)
    canonical.add_page_ids(other.page_ids)
  end

  class ResultRow
    attr_reader :nodes, :page_ids

    def initialize(row, query, query_uris)
      @nodes = []
      @page_ids = Set.new(row[:page_ids])

      @nodes = query.page_count_sorted_filters.map.with_index do |_, i|
        uri_key = :"child#{i}_uri"
        uri = row[uri_key]
        node_query = query.deep_dup
        node_query.page_count_sorted_filters[i].obj_uri = uri 

        Node.new(
          uri,
          i,
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
      !!(@nodes.find { |n| n && n.query_term? })
    end

    def remove_page_ids(to_remove)
      @page_ids.subtract(to_remove)
    end

    def add_page_ids_to_nodes
      @nodes.each { |n| n.add_page_ids(@page_ids) if n }
    end
  end

  class Node
    attr_reader :uri, :axis_id, :page_ids, :query

    def initialize(uri, axis_id, is_query_term, query)
      @uri = uri
      @axis_id = axis_id
      @is_query_term = is_query_term
      @query = query
    end

    def query_term?
      @is_query_term
    end

    def size
      @page_ids.length
    end

    def add_page_ids(other)
      @page_ids ||= Set.new
      @page_ids.merge(other)
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
      @page_ids = page_ids
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
