class Page < ActiveRecord::Base
  belongs_to :native_node, class_name: "Node"
  belongs_to :moved_to_page, class_name: "Page"

  has_many :nodes, inverse_of: :page
  has_many :page_contents, inverse_of: :page
  has_many :vernaculars, inverse_of: :page
  has_many :scientific_names, inverse_of: :page
  has_many :page_contents, inverse_of: :page
  # TODO: content types... preferred vernacular... and much more!
end
