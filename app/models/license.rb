class License < ActiveRecord::Base
  has_many :articles, inverse_of: :license
  has_many :links, inverse_of: :license
  has_many :maps, inverse_of: :license
  has_many :media, inverse_of: :license
end
