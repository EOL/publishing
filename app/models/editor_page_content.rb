class EditorPageContent < ApplicationRecord
  belongs_to :editor_page
  validates_presence_of :status, :locale, :title, :content
  validates_inclusion_of :locale, in: I18n.available_locales.map { |l| l.to_s }
  validates_uniqueness_of :editor_page_id, scope: %i(locale status) 

  has_many_attached :images

  enum status: {
    draft: 0,
    published: 1
  }
end
