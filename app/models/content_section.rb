class ContentSection < ApplicationRecord
  belongs_to :content, polymorphic: true
  belongs_to :section
end
