# Represents an I18n 'locale', which is really a language code
class Locale < ApplicationRecord
  has_many :languages
  validates :code, presence: true, uniqueness: true

  TSV_PATH = Rails.application.root.join('db', 'seed_data', 'languages_locales.tsv')

  class << self
    def rebuild_from_tsv
          
    end
  end
end
