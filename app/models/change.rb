class Change < ApplicationRecord
  belongs_to :user # Never null; a user always effected the change.
  belongs_to :activity, polymorphic: true
  belongs_to :page # NOTE: can be null; not all activities affect a page.

  # NOTE: the other fields are changed_field, changed_from, changed_to, and trait.
end
