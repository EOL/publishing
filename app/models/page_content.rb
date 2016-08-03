class PageContent < ActiveRecord::Base
  belongs_to :page
  belongs_to :source_page, class: "Page"
  belongs_to :content, polymorphic: true
  belongs_to :association_add_by_user, class: "User"

  has_many :curations

  acts_as_list scope: :page
end
