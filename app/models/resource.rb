class Resource < ActiveRecord::Base
  belongs_to :partner, inverse_of: :resources

  has_many :nodes, inverse_of: :resource
  has_many :articles, as: :provider
  has_many :links, as: :provider
  has_many :maps, as: :provider
  has_many :media, as: :provider

  class << self
    def native
      where(name: "EOL Dynamic Working Hierarchy").first_or_create do |r|
        r.name = "EOL Dynamic Working Hierarchy"
      end
    end
  end
end
