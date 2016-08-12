class Section < ActiveRecord::Base
  has_many :content_sections
  belongs_to :parent, class_name: "Section"

  has_many :content_sections
  has_many :contents, through: :content_sections
  has_many :children, class_name: "Section", foreign_key: "parent_id", inverse_of: :parent

  acts_as_list
end
