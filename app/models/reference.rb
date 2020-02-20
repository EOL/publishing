# A reference is any kind of "annotation" that was in the resource file attached
# to a row of data. It's a bit of a miscellaneous bucket. NOTE that THIS class
# is the relationship between the referent (the actual note) and the object; it
# does not contain any text itself.
class Reference < ApplicationRecord
  belongs_to :referent, inverse_of: :references
  belongs_to :parent, polymorphic: true, inverse_of: :references
end
