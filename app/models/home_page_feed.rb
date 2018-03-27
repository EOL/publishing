class HomePageFeed < ActiveRecord::Base
  validates :name, :presence => true, :uniqueness => true
  validate :validate_field_mask

  has_many :items, :class_name => "HomePageFeedItems", :inverse_of => :home_page_feed
  accepts_nested_attributes_for :items
  validates_associated :items

  # XXX: don't ever change the order of these. Append only.
  FIELDS = [:img_url, :link_url, :label, :desc]

  def fields=(fields)
    self.field_mask = fields.reject{ |f| f.blank? }.map { |f| 2**FIELDS.index(f.to_sym) }.inject(0, :+)
  end

  def fields
    FIELDS.reject do |f|
      !has_field?(f)
    end
  end

  def has_field?(field)
    !((self.field_mask || 0) & 2**FIELDS.index(field.to_sym)).zero?
  end

  private
  def validate_field_mask
    if !self.field_mask || self.field_mask == 0
      errors.add(:fields, "must pick at least one")
    end
  end
end
