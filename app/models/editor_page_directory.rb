class EditorPageDirectory < ApplicationRecord
  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-zA-Z0-9\-\_]+\z/, message: "only allows letters, numbers, dashes, and underscores" }
  has_many :editor_pages, dependent: :destroy
end
