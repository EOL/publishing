class Role
  has_many :attributions, inverse_of: :role
end
