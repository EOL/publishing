class Collecting < ApplicationRecord
  belongs_to :collection # If null, this must be a delete-collection.
  belongs_to :user
  # NOTE: "content" is OVERLOADED (!) for users who are added to and removed
  # from the collection. The terminology becomes unclear, so be mindful: the
  # page_id will be blank in this case.
  belongs_to :content, polymorphic: true # Only used in the case of collected media.
  belongs_to :page # If null, this was either a delete-collection, user change, or a field change.
  belongs_to :associated_collection, class_name: "Collection" # Only used in the obvious case.

  # NOTE: other fields: changed_field, changed_from, changed_to

  enum action: [:add, :change, :remove]
end
