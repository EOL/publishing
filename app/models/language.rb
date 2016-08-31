class Language < ActiveRecord::Base
  has_many :articles, inverse_of: :license
  has_many :links, inverse_of: :license
  has_many :maps, inverse_of: :license
  has_many :media, inverse_of: :license
  has_many :vernaculars, inverse_of: :license

  class << self
    def english
      @english ||= where(code: "eng").first_or_create do |l|
        l.code = "eng"
        l.group = "en"
        l.can_browse_site = true
      end
    end

    def current
      locale = I18n.locale
      @current ||= {}
      @current[locale] ||= Language.find_by_group(locale)
    end
  end
end
