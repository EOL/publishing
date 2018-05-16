class ContentSection < ActiveRecord::Base
  belongs_to :content, polymorphic: true
  belongs_to :section
end
