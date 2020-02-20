class Language < ApplicationRecord
  has_many :articles, inverse_of: :license
  has_many :links, inverse_of: :license
  has_many :media, inverse_of: :license
  has_many :vernaculars, inverse_of: :license
  has_many :vernacular_preferences, inverse_of: :license

  class << self
    def english
      Rails.cache.fetch("languages/english") do
        where(code: "eng").first_or_create do |l|
          l.code = "eng"
          l.group = "en"
          l.can_browse_site = true
        end
      end
    end

    def current
      locale = I18n.locale
      Rails.cache.fetch("languages/current/#{locale}") do
        l = Language.find_by_group(locale)
        l || Language.english
      end
    end

    def cur_group
      self.current.group
    end
  end
end
