class Collecting < ActiveRecord::Base
  belongs_to :collection
  belongs_to :user
  belongs_to :content, polymorphic: true # Can be null
  belongs_to :page # Can be null

  # NOTE: other fields: changed_field, changed_from, changed_to

  enum action: [:add, :change, :remove]
end
