class Curation < ActiveRecord::Base
  belongs_to :user, inverse_of: :curations
  belongs_to :page_content, inverse_of: :curations

  has_one :page, through: :page_content
  # TODO: I don't think this will work:
  has_one :contents, through: :page_content

  enum trust: [ :unreviewed, :trusted, :untrusted ]
end
