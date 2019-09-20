class HomePageFeed < ActiveRecord::Base
  validates :name, :presence => true, :uniqueness => true
  validate :validate_field_mask

  has_many :items, :dependent => :destroy, :class_name => "HomePageFeedItem", :inverse_of => :home_page_feed
  accepts_nested_attributes_for :items
  validates_associated :items

  # Don't change these mappings. Add as necessary.
  FIELDS = {
    :img_url => 0, 
    :link_url => 1, 
    :label => 2, 
    :desc => 3,
    :page_id => 4
  }

  def fields=(fields)
    self.field_mask = fields.reject{ |f| f.blank? }.map { |f| 2**FIELDS[f.to_sym] }.inject(0, :+)
  end

  def fields
    FIELDS.keys.reject do |f|
      !has_field?(f)
    end
  end

  def has_field?(field)
    !((field_mask || 0) & 2**FIELDS[field.to_sym]).zero?
  end

  def draft_version
    published_version + 1
  end

  def published_items
    items.where(:feed_version => published_version)
  end

  def draft_items
    items.where(:feed_version => draft_version)
  end

  def publish!
    self.published_version = draft_version
    items << published_items.reload.map do |item|
      new_item = item.dup
      new_item.feed_version = draft_version
      new_item
    end
    save!
  end

  private
  def validate_field_mask
    if !field_mask || field_mask == 0
      errors.add(:fields, "must pick at least one")
    end
  end
end
