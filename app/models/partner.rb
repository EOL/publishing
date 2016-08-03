class Partner < ActiveRecord::Base
  has_many :resources, inverse_of: :partner
  has_and_belongs_to_many :users
end
