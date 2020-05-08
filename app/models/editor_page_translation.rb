class EditorPageTranslation < ApplicationRecord
  validates_presence_of :title, :content, :locale, :editor_page_id
  validates_inclusion_of :locale, in: I18n.available_locales
  validates_uniqueness_of :editor_page_id, scope: :locale

  belongs_to :editor_page
  has_many :editor_page_contents
end
