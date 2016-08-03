class Resource < ActiveRecord::Base
  belongs_to :partner, inverse_of: :resources

  has_many :nodes, inverse_of: :resource
  has_many :articles, as: :provider
  has_many :links, as: :provider
  has_many :maps, as: :provider
  has_many :media, as: :provider
end
