class License < ActiveRecord::Base
  has_many :articles, inverse_of: :license
  has_many :links, inverse_of: :license
  has_many :media, inverse_of: :license

  class << self
    def public_domain
      Rails.cache.fetch("licenses/public_domain") do
        License.where(name: "public domain").first_or_create do |l|
          l.name = "public domain"
          l.source_url = "https://creativecommons.org/publicdomain/"
          # l.icon_url = "" TODO later!
          l.can_be_chosen_by_partners = true
        end
      end
    end

    def types
      Rails.cache.fetch("licenses/types") do
        all.select(:name).map { |l| l.name.sub(/\s*\d+.?\d*\s*$/, "") }.
          compact.uniq.sort
      end
    end
  end
end
