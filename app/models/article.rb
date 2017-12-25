class Article < ActiveRecord::Base
  include Content
  include Content::Attributed

  alias_attribute :description, :body

  # has_and_belongs_to_many :references
  
  enum mime_type: [ 'text/html', 'text/plain' ]

  def first_section
    @first_section ||= sections.sort_by { |s| s.position }.first
  end
end
