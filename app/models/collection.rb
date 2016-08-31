class Collection < ActiveRecord::Base
  has_many :collection_items, -> { order(position: :asc) }, inverse_of: :collection

  # TODO: Check these. Not sure if it's more efficient to use scopes:
  has_many :articles, through: :collection_items, source: :item, source_type: "Article"
  has_many :media, through: :collection_items, source: :item, source_type: "Medium"
  has_many :pages, through: :collection_items, source: :item, source_type: "Page"

  has_and_belongs_to_many :users
  has_and_belongs_to_many :managers,
    -> { where(is_manager: true) },
    class_name: "User",
    association_foreign_key: "user_id"

  has_attached_file :icon

  accepts_nested_attributes_for :collection_items

  validates_attachment_content_type :icon, content_type: /\Aimage\/.*\Z/
end
