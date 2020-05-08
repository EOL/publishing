class EditorPageTranslation < ApplicationRecord
  validates_inclusion_of :locale, in: I18n.available_locales.map { |l| l.to_s }
  validates_uniqueness_of :editor_page_id, scope: :locale

  belongs_to :editor_page
  has_many :editor_page_contents

  def draft
    editor_page_contents.where(status: :draft)&.first
  end

  def published
    editor_page_contents.where(status: :published)&.first
  end
end
