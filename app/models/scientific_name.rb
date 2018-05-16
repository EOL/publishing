class ScientificName < ActiveRecord::Base
  belongs_to :node, inverse_of: :scientific_names
  # belongs_to :resource, inverse_of: :scientific_names
  belongs_to :taxonomic_status, inverse_of: :scientific_names
  # DENORMALIZED:
  belongs_to :page, inverse_of: :scientific_names

  scope :preferred, -> { where(is_preferred: true) }
  scope :synonym, -> { where(is_preferred: false) }

  counter_culture :page

  def <=>(other)
    italicized <=> other.italicized
  end
end
