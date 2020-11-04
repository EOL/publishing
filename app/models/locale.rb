# Represents an I18n 'locale', which is really a language code

require 'csv'

class Locale < ApplicationRecord
  has_many :languages
  has_many :fallback_locales, class: 'Locale', through: :fallback_locales
  validates :code, presence: true, uniqueness: true

  CSV_PATH = Rails.application.root.join('db', 'seed_data', 'languages_locales.csv')

  class << self
    def rebuild_from_csv
      rows = CSV.read(CSV_PATH, headers: true)
      locale_codes = rows.map { |r| r["locale"] }.uniq
      puts 'syncing locales'
      sync_locales(locale_codes)
      puts 'updating languages'
      update_language_locales(rows)
      puts 'done'
    end

    private

    def sync_locales(locale_codes)
      existing_codes = Locale.all.pluck(:code)
      new_codes = locale_codes.select { |l| !existing_codes.include?(l) }
      obsolete_codes = existing_codes.select { |l| !locale_codes.include?(l) } 
      puts "WARNING: locale codes #{obsolete_codes.join(', ')} were found in the DB but weren't present in the csv. You might want to delete them manually. Continuing." if obsolete_codes.any?

      new_locale_data = new_codes.map { |c| { code: c } }
      self.create!(new_locale_data)
    end

    def update_language_locales(rows)
      languages_by_code = Language.all.map { |l| [l.code, l] }.to_h
      locales_by_code = Locale.all.map { |l| [l.code, l] }.to_h
      
      self.transaction do
        rows.each do |row|
          language = languages_by_code[row["language"]]
          locale = locales_by_code[row["locale"]] # guaranteed to exist because of sync_locales step
          
          if language.nil?
            puts "WARNING: missing language #{row["language"]}, skipping row #{row}"
            next
          end

          language.locale = locale
          language.save! 
        end
      end
    end
  end
end
