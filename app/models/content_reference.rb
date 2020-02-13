class ContentReference < ApplicationRecord
  belongs_to :reference, inverse_of: :content_references
  belongs_to :content, polymorphic: true
end
