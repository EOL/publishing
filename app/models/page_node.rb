class PageNode
  include Neo4j::ActiveNode

  id_property :page_id
  property :descendant_count, default: 0

  self.mapped_label_name = 'Page'
end
