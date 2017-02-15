class Reference < ActiveRecord::Base
  belongs_to :referent, inverse_of: :references
  belongs_to :parent, polymorphic: true, inverse_of: :references
end
