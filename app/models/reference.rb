class Reference < ActiveRecord::Base
  has_many :content_references, inverse_of: :reference
  has_many :contents, through: :content_references
end
