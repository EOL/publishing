class ContentEdit < ApplicationRecord
  belongs_to :user
  belongs_to :page_content

  # NOTE: other fields: changed_field, changed_from, changed_to, comment
end
