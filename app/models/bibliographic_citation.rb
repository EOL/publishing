# A bibliographic citation is a specific reference to a written document. Only
# media and articles may have these.
class BibliographicCitation < ApplicationRecord
  has_many :articles, inverse_of: :bibliographic_citation
  has_many :media, inverse_of: :bibliographic_citation

  def contents
    (articles + media).compact
  end
end
