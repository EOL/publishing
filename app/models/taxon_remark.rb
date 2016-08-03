class TaxonRemark < ActiveRecord::Base
  belongs_to :node, inverse_of: :taxon_remark
end
