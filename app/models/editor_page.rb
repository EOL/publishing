class EditorPage < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: true
  has_many :editor_page_translations

  def translation_for_locale(locale)
    editor_page_translations.where(locale: locale)&.first
  end
end
