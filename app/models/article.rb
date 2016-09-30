class Article < ActiveRecord::Base
  include Content
  include Content::Attributed

  has_and_belongs_to_many :references
end
