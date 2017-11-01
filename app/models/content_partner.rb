class ContentPartner
  include ActiveModel::Model
  attr_accessor :id, :name, :abbreviation, :url, :description, :logo, :logo_type, :resources, :user, :created_at
  validates :name, presence: true
  validates :description, presence: true
end