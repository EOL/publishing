class Article < ActiveRecord::Base
  include Content
  include Content::Attributed

  has_and_belongs_to_many :references

  def first_section
    @first_section ||= sections.sort_by { |s| s.position }.first
  end
end
