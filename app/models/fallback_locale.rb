class FallbackLocale < ApplicationRecord
  belongs_to :locale
  belongs_to :fallback_locale, class: 'Locale'

  validates_presence_of :locale_id
  validates :fallback_locale_id, presence: true, uniqueness: { scope: [:locale_id] }
  validates :position, presence: true, uniqueness: { scope: [:locale_id] }
end
