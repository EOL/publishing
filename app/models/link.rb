class Link < ActiveRecord::Base
  include Content
  
  belongs_to :provider, polymorphic: true # User or Resource
  belongs_to :language
end
