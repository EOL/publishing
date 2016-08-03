class Collection < ActiveRecord::Base
  has_many :collection_items, -> { order(position: :asc) }

  # TODO: Check these. Not sure if it's more efficient to use scopes:
  has_many :articles, through: :collection_items, source: :item, source_type: "Article"
  has_many :media, through: :collection_items, source: :item, source_type: "Medium"
  has_many :pages, through: :collection_items, source: :item, source_type: "Page"

  has_and_belongs_to_many :users
  has_and_belongs_to_many :managers,
    class_name: "User",
    association_foreign_key: "user_id",
    -> { where(is_manager: true) }

  has_attached_file :icon

  validates_attachment_content_type :icon, content_type: /\Aimage\/.*\Z/
end
