class Language < ApplicationRecord
  has_many :articles, inverse_of: :license
  has_many :links, inverse_of: :license
  has_many :media, inverse_of: :license
  has_many :vernaculars, inverse_of: :license
  has_many :vernacular_preferences, inverse_of: :license

  class << self
    def english_default
      Rails.cache.fetch("languages/english") do
        where(code: "eng").first_or_create do |l|
          l.code = "eng"
          l.group = "en"
          l.can_browse_site = true
        end
      end
    end

    def english
      self.for_locale("en")
    end


    def for_locale(locale)
      locale_str = locale.downcase
      Rails.cache.fetch("languages/for_locale/#{locale_str}") do
        Language.where(group: locale_str)
      end
    end

    def current
      Rails.cache.fetch("languages/current_by_group/#{I18n.locale}") do
        l = self.for_locale(I18n.locale)

        if l.empty?
          logger.error("Language.current -- missing group for locale #{locale}. Falling back to Language.english")
          l = english
        end

        l
      end
    end

    def cur_group
      self.current.first.group
    end

    def first_matching_record(languages, records)
      records.find { |r| languages.find { |l| r.language_id = l.id }.present? }
    end

    def all_matching_records(languages, records)
      records.select { |r| languages.find { |l| r.language_id = l.id }.present? }
    end
  end
end
