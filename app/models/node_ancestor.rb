class NodeAncestor < ApplicationRecord
  belongs_to :node, inverse_of: :node_ancestors
  belongs_to :ancestor, class_name: 'Node', inverse_of: :descendants
end
