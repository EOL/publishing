class Javascript < ActiveRecord::Base
  has_many :articles, inverse_of: :javascript

  def contents
    (articles + media).compact
  end
end
