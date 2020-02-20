# An attribution is a record of a specific agent with a specific role involved
# in the creation or ownership of this object. ...For example, an author, a
# photographer, a copyright holder, and so on.
class Attribution < ApplicationRecord
  belongs_to :role, inverse_of: :attributions
  belongs_to :content, polymorphic: true, optional: true
end
