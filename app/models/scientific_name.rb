class ScientificName < ActiveRecord::Base
  belongs_to :node, inverse_of: :scientific_names
  belongs_to :resource, inverse_of: :scientific_names
  belongs_to :taxonomic_status, inverse_of: :scientific_names
  # DENORMALIZED:
  belongs_to :page, inverse_of: :scientific_names

  scope :preferred, -> { where(is_preferred: true) }
  scope :synonym, -> { where(is_preferred: false) }

  counter_culture :page

  TAXONOMIC_TO_DISPLAY_STATUS = {
    "accepted" => "preferred"
  }

  # scientific_names.id >= 17100001
  def self.re_de_normalize_page_ids(scope = nil)
    scope ||= '1=1' # ALL
    min = where(scope).minimum(:id)
    max = where(scope).maximum(:id)
    # This can be quite large, as this is a relatively fast query. (Note it's a big table, so this still requires a long
    # time OVERALL.)
    batch_size = 50_000
    while min < max
      where(scope).joins(:node).
        where(['nodes.page_id IS NOT NULL AND scientific_names.id >= ? AND scientific_names.id < ?', min, min + batch_size]).
        update_all('scientific_names.page_id = nodes.page_id')
      min += batch_size
    end
  end

  def <=>(other)
    italicized <=> other.italicized
  end

  def display_status
    TAXONOMIC_TO_DISPLAY_STATUS[taxonomic_status.name] || taxonomic_status.name
  end
end
