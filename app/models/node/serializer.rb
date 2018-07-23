class Node::Serializer
  class << self
    def store_clade(node)
      serializer = new(node)
      serializer.store_clade
    end
  end

  def initialize(node)
    @node = node
    @nodes_dir = Rails.root.join('public', 'data', 'nodes')
    Dir.mkdir(nodes_dir.to_s, 0755) unless Dir.exist?(nodes_dir.to_s)
    @nodes_dir = @nodes_dir.join(@node.id)
    Dir.mkdir(nodes_dir.to_s, 0755) unless Dir.exist?(nodes_dir.to_s)
    @filenames = []
  end

  def filename_for(table)
    nodes_dir.join("#{table}.csv")
  end

  def store_clade
    # Gather ye rosebuds while ye may:
    
    @filenames
  end
end
