class ContentReposition < ApplicationRecord
  belongs_to :user
  belongs_to :content, polymorphic: true

  # NOTE: other fields: changed_from, changed_to
end
