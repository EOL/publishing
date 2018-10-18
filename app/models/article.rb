class Article < ActiveRecord::Base
  include Content
  include Content::Attributed

  alias_attribute :description, :body

  has_many :references, as: :parent
  has_many :referents, through: :references

  def first_section
    @first_section ||= sections.sort_by { |s| s.position }.first
  end
end
