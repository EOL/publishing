class ScientificName < ActiveRecord::Base
  belongs_to :node, inverse_of: :scientific_names
  belongs_to :taxonomic_status, inverse_of: :scientific_names
  # DENORMALIZED:
  belongs_to :page, inverse_of: :scientific_names
end
