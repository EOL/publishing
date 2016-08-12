class PageContent < ActiveRecord::Base
  belongs_to :page
  belongs_to :source_page, class_name: "Page"
  belongs_to :content, polymorphic: true
  belongs_to :association_add_by_user, class_name: "User"

  has_many :curations

  enum trust: [ :trusted, :unreviewed, :untrusted ]

  # TODO: think about this. We might want to make the scope [:page,
  # :content_type]... then we can interlace other media types (or always show
  # them separately, which I think has advantages)
  acts_as_list scope: :page
end
