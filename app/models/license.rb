class License < ActiveRecord::Base
  has_many :articles, inverse_of: :license
  has_many :links, inverse_of: :license
  has_many :maps, inverse_of: :license
  has_many :media, inverse_of: :license

  class << self
    def public_domain
      @public_domain ||= License.where(name: "public domain").first_or_create do |l|
        l.name = "public domain"
        l.source_url = "https://creativecommons.org/publicdomain/"
        # l.icon_url = "" TODO later!
        l.can_be_chosen_by_partners = true
      end
    end
  end
end
