class BibliographicCitation < ActiveRecord::Base
  has_many :articles, inverse_of: :bibliographic_citation
  has_many :media, inverse_of: :bibliographic_citation

  def contents
    (articles + media).compact
  end
end
