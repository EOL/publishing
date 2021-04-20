require 'set'

class Traits::DataViz::TaxonSummary
  def initialize(query)
    results = TraitBank::Stats.taxon_summary_data(query)
    page_ids = Set.new
    results.each do |row|
      page_ids.add(row[:group_taxon_id])
      page_ids.add(row[:taxon_id])
    end

    pages_by_id = Page.where(id: page_ids).map { |p| [p.id, p] }.to_h

    group_nodes_by_id = {}    

    results.each do |row|
      group_taxon = get_page(pages_by_id, row[:group_taxon_id])
      taxon = get_page(pages_by_id, row[:taxon_id])
      count = row[:count]

      group_node = group_nodes_by_id[group_taxon.id]
      if group_node.nil?
        group_node = GroupNode.new(group_taxon)
        group_nodes_by_id[group_taxon.id] = group_node
      end

      group_node.add_child(InnerNode.new(taxon, count))
    end

    @group_nodes = group_nodes_by_id.values
  end

  def to_json
    # d3 requires a root node even though we're going to ignore it
    {
      name: 'root',
      children: @group_nodes.map { |n| n.to_h }
    }.to_json
  end

  def length
    @group_nodes.length
  end

  def any?
    @group_nodes.any?
  end

  private
  def get_page(pages_by_id, page_id)
    raise TypeError, "invalid page id in results: #{page_id}" unless pages_by_id.include?(page_id)

    pages_by_id[page_id]
  end

  class GroupNode
    def initialize(page)
      @page = page
      @children = Set.new
    end

    def add_child(node)
      @children.add(node)
    end

    def count
      @children.reduce(0) { |total, c| total + c.count }
    end

    def to_h
      {
        pageId: @page.id,
        name: @page.name,
        children: @children.map { |c| c.to_h }
      }
    end
  end

  InnerNode = Struct.new(:page, :count) do 
    def to_h
      {
        pageId: page.id,
        name: page.name,
        count: count
      }
    end
  end
end
