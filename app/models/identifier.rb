class Identifier < ApplicationRecord
  belongs_to :node, inverse_of: :identifiers
end
