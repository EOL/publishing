class Location < ActiveRecord::Base
  has_many :articles, inverse_of: :stylesheet
  has_many :media, inverse_of: :stylesheet

  def contents
    (articles + media).compact
  end
end
