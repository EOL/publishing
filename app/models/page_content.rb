class PageContent < ActiveRecord::Base
  belongs_to :page
  belongs_to :source_page, class_name: "Page"
  belongs_to :content, polymorphic: true, inverse_of: :page_contents
  belongs_to :association_add_by_user, class_name: "User"

  has_many :curations

  default_scope { order(:position) }

  enum trust: [ :unreviewed, :trusted, :untrusted ]

  scope :visible, -> { where(is_hidden: false) }
  scope :hidden, -> { where(is_hidden: true) }

  scope :trusted, -> { where(trust: PageContent.trusts[:trusted]) }
  scope :untrusted, -> { where(trust: PageContent.trusts[:untrusted]) }
  scope :not_untrusted, -> { where.not(trust: PageContent.trusts[:untrusted]) }

  scope :articles, -> { where(content_type: "Article") }

  scope :media, -> { where(content_type: "Medium") }
  scope :media_by_subclass, -> subclass {
    Medium.where(id: joins("JOIN media ON (media.id = "\
      "page_contents.content_id AND media.subclass = "\
      "'#{Medium.subclasses[subclass]}')").
    where(content_type: "Medium").pluck(:content_id)) }
  scope :images, -> { media_by_subclass(:image) }
  scope :sounds, -> { media_by_subclass(:sound) }
  scope :videos, -> { media_by_subclass(:video) }

# TODO: make sure these both work.
  counter_culture :page
  counter_culture :page, column_name: proc { |model| "#{model.content_type.pluralize.downcase}_count" }

  # TODO: think about this. We might want to make the scope [:page,
  # :content_type]... then we can interlace other media types (or always show
  # them separately, which I think has advantages)
  acts_as_list scope: :page
end
