# A very specific kind of remark used only in the context of a node, explaining
# why the node is included in the hierarchy and what is known about the name.
class TaxonRemark < ActiveRecord::Base
  belongs_to :node, inverse_of: :taxon_remark
end
