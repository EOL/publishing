class TermQuery < ActiveRecord::Base
  has_many :filters,
    :class_name => "TermQueryFilter",
    :dependent => :destroy
  has_one :user_download, :dependent => :destroy
  belongs_to :clade, :class_name => "Page"

  accepts_nested_attributes_for :filters

  def initialize(*)
    super
  end

  def search_filters
    filters.reject { |f| f.invalid? }
  end
end
