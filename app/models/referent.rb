class Referent < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
  belongs_to :resource, inverse_of: :referents

  has_many :references, inverse_of: :referent
  has_many :articles, through: :references,
    source: :parent, source_type: "Article"
  has_many :links, through: :references,
    source: :parent, source_type: "Link"
  has_many :media, through: :references,
    source: :parent, source_type: "Medium"

  has_and_belongs_to_many :pages

end
