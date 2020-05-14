class EditorPage < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: true
  has_many :editor_page_contents, dependent: :destroy
  belongs_to :editor_page_directory, required: false

  scope :top_level, -> { where(editor_page_directory_id: nil) }

  def draft_for_locale(locale)
    editor_page_contents.where(locale: locale, status: :draft)&.first
  end

  def published_for_locale(locale)
    editor_page_contents.where(locale: locale, status: :published)&.first
  end

  # These raise a not found error, like find
  def find_draft_for_locale(locale)
    editor_page_contents.find_by!(locale: locale, status: :draft)
  end

  def find_published_for_locale(locale)
    editor_page_contents.find_by!(locale: locale, status: :published)
  end

  def to_param
    id
  end
end
