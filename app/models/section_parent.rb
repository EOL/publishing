class SectionParent < ApplicationRecord
  belongs_to :section
  belongs_to :parent, class_name: 'Section'
end
