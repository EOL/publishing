class Stylesheet < ActiveRecord::Base
  has_many :articles, inverse_of: :stylesheet
  has_many :maps, inverse_of: :stylesheet
  has_many :media, inverse_of: :stylesheet

  def contents
    (articles + maps + media).compact
  end
end
