class EditorPage < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: true
  has_many :editor_page_contents

  def draft_for_locale(locale)
    editor_page_contents.where(locale: locale, status: :draft)&.first
  end

  def published_for_locale(locale)
    editor_page_contents.where(locale: locale, status: :published)&.first
  end
end
