class Javascript < ActiveRecord::Base
  has_many :articles, inverse_of: :javascript
  has_many :maps, inverse_of: :javascript
  has_many :media, inverse_of: :javascript

  def contents
    (articles + maps + media).compact
  end
end
