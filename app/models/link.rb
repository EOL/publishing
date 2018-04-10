class Link < ActiveRecord::Base
  include Content

  alias_attribute :description, :body
  
  belongs_to :provider, polymorphic: true # User or Resource
  belongs_to :language
end
