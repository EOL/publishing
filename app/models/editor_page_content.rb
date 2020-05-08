class EditorPageContent < ApplicationRecord
  belongs_to :editor_page_translation
  validates_presence_of :status
  validates_uniqueness_of :editor_page_translation_id, scope: :status

  enum status: {
    draft: 0,
    published: 1
  }
end
