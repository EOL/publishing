class Collection < ActiveRecord::Base
  searchkick

  has_many :collection_associations, -> { order(position: :asc) },
    inverse_of: :collection
  has_many :collections, through: :collection_associations,
    source: :associated
  has_many :collected_pages, -> { order(position: :asc) },
    inverse_of: :collection, dependent: :destroy
  has_many :pages, through: :collected_pages

  has_and_belongs_to_many :users

  has_attached_file :icon

  accepts_nested_attributes_for :collection_associations, allow_destroy: true
  accepts_nested_attributes_for :collected_pages, allow_destroy: true

  validates_attachment_content_type :icon, content_type: /\Aimage\/.*\Z/
  validates :name, presence: true

  enum collection_type: [ :normal, :gallery ]
  enum default_sort: [ :position, :sci_name, :sci_name_rev, :sort_field,
    :sort_field_rev, :hierarchy ]

end
