class Identifier < ActiveRecord::Base
  belongs_to :node, inverse_of: :identifiers
end
