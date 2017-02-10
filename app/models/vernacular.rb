class Vernacular < ActiveRecord::Base
  belongs_to :language
  belongs_to :node, inverse_of: :vernaculars
  # DENORMALIZED:
  belongs_to :page, inverse_of: :vernaculars

  scope :preferred, -> { where(is_preferred: true) }
  scope :nonpreferred, -> { where(is_preferred: false) }
  scope :current_language, -> { where(language_id: Language.current.id) }

  enum trust: [ :unreviewed, :trusted, :untrusted ]

  def <=>(other)
    string <=> other.string
  end
end
