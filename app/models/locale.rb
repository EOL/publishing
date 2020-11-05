# Represents an I18n 'locale', which is really a language code

require 'csv'

class Locale < ApplicationRecord
  has_many :languages
  has_many :ordered_fallback_locales
  validates :code, presence: true, uniqueness: true

  before_save { code.downcase! }

  default_scope { includes(:languages) }

  CSV_PATH = Rails.application.root.join('db', 'seed_data', 'languages_locales.csv')

  def fallbacks
    self.ordered_fallback_locales.includes(:fallback_locale).order(position: 'asc').map { |r| r.fallback_locale }
  end

  class << self
    def current
      Locale.find_by_code(I18n.locale.downcase)
    end

    def english
      Locale.find_by_code("en")
    end

    # INTENDED FOR OFFLINE USE ONLY
    def rebuild_language_mappings
      rows = CSV.read(CSV_PATH, headers: true, skip_blanks: true)
      puts 'updating language -> locale mappings'
      update_language_locales(rows)
      puts 'done'
    end

    def all_by_code
      @all_by_code ||= Locale.all.map { |l| [l.code, l] }.to_h
    end


    def get_or_create!(code)
      if all_by_code.include?(code)
        all_by_code[code]
      else
        puts "Locale #{code} not found in db, creating..."
        new_locale = Locale.create!(code: code)
        all_by_code[code] = new_locale
        new_locale
      end
    end
    # END

    private

    def update_language_locales(rows)
      languages_by_code = Language.all.map { |l| [l.code, l] }.to_h
      
      self.transaction do
        rows.each do |row|
          puts "handling row #{row}"
          language = get_or_create_language(languages_by_code, row)
          locale = get_or_create!(row['locale'])
          language.locale = locale
          language.save! 
        end
      end
    end

    def get_or_create_language(languages_by_code, row)
      code = row['language']

      if languages_by_code.include?(code)
        languages_by_code[code]
      else
        puts "Language #{code} not found in db, creating..."
        Language.create!(code: code, group: code) # TODO: get rid of group when the column is removed. This is just here to prevent a null error.
      end
    end

  end
end
