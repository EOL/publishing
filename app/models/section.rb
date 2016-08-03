class Section < ActiveRecord::Base
  belongs_to :parent, class: "Section"

  has_many :content_sections
  has_many :contents, through: :content_sections
  has_many :children, class: "Section", foreign_key: "parent_id", inverse_of: :parent

  acts_as_list
end
