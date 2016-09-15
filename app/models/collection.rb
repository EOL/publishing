class Collection < ActiveRecord::Base
  has_many :collection_items, -> { order(position: :asc) },
    inverse_of: :collection
  has_many :collected_pages, -> { order(position: :asc) },
    inverse_of: :collection
  has_many :pages, through: :collected_pages

  # TODO: Check these. Not sure if it's more efficient to use scopes:
  has_many :articles, through: :collection_items, source: :item,
    source_type: "Article"
  has_many :media, through: :collection_items, source: :item,
    source_type: "Medium"
  has_many :links, through: :collection_items, source: :item,
    source_type: "Link"
  has_many :users, through: :collection_items, source: :item,
    source_type: "User"
  has_many :associated_collections, through: :collection_items, source: :item,
    class_name: "Collection", source_type: "Collection"

  has_and_belongs_to_many :users
  has_and_belongs_to_many :managers,
    -> { where(is_manager: true) },
    class_name: "User",
    association_foreign_key: "user_id"

  has_attached_file :icon

  accepts_nested_attributes_for :collection_items, allow_destroy: true
  accepts_nested_attributes_for :collected_pages, allow_destroy: true

  validates_attachment_content_type :icon, content_type: /\Aimage\/.*\Z/
  validates :name, presence: true
end
