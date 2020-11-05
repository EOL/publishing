# Represents an I18n 'locale', which is really a language code

require 'csv'

class Locale < ApplicationRecord
  has_many :languages
  has_many :fallback_locales, class_name: 'Locale', through: :fallback_locales
  validates :code, presence: true, uniqueness: true

  CSV_PATH = Rails.application.root.join('db', 'seed_data', 'languages_locales.csv')

  class << self
    # INTENDED FOR OFFLINE USE ONLY
    def rebuild_from_csv
      rows = CSV.read(CSV_PATH, headers: true, skip_blanks: true)
      locale_codes = rows.map { |r| r["locale"] }.uniq
      puts 'syncing locales'
      sync_locales(locale_codes)
      puts 'updating languages'
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

    def sync_locales(locale_codes)
    #  existing_codes = Locale.all.pluck(:code)
    #  new_codes = locale_codes.select { |l| !existing_codes.include?(l) }
    #  obsolete_codes = existing_codes.select { |l| !locale_codes.include?(l) } 
    #  puts "WARNING: locale codes #{obsolete_codes.join(', ')} were found in the DB but weren't present in the csv. You might want to delete them manually. Continuing." if obsolete_codes.any?

    #  new_locale_data = new_codes.map { |c| { code: c } }
    #  self.create!(new_locale_data)
    end

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
