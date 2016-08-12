class Partner < ActiveRecord::Base
  has_many :resources, inverse_of: :partner
  has_and_belongs_to_many :users

  class << self
    def native
      where(full_name: "Encyclopedia of Life").first_or_create do |r|
        r.full_name = "Encyclopedia of Life"
        r.short_name = "EOL"
        r.homepage_url = "http://eol.org"
        r.description = "EOL seeks to build a webpage for every species and to "\
          "provide global access to knowledge about life on Earth"
      end
    end
  end
end
