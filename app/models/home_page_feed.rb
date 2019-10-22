require "csv"
require "set"

class HomePageFeed < ActiveRecord::Base
  validates :name, :presence => true, :uniqueness => true
  validate :validate_field_mask
  validate :validate_csv_errors

  has_many :items, :dependent => :destroy, :class_name => "HomePageFeedItem", :inverse_of => :home_page_feed
  accepts_nested_attributes_for :items
  validates_associated :items

  before_update :delete_old_draft_if_necessary

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

  def reset_draft
    draft_items.reload.destroy_all
    items << published_items.reload.map do |item|
      new_item = item.dup
      new_item.feed_version = draft_version
      new_item
    end
  end

  def publish!
    self.published_version = draft_version
    reset_draft
    save!
  end

  def items_from_csv=(csv_str)
    @csv_errors = []
    @items_from_csv = csv_str 

    begin
      csv = CSV.parse(csv_str, headers: true, col_sep: "\t")
      headers_sym = csv.headers.collect { |h| h.to_sym }
      field_set = Set.new(fields)

      raise "can't be blank" if !csv.any?

      headers_sym.each do |h|
        if !field_set.include? h
          raise "invalid column header: #{h}"
        end
      end

      self.items_attributes = csv.collect(&:to_h)
      @delete_old_draft_on_update = true
    rescue => e
      @csv_errors << e.message
    end 
  end

  def items_from_csv
    @items_from_csv
  end

  private
  def validate_field_mask
    if !field_mask || field_mask == 0
      errors.add(:fields, "must pick at least one")
    end
  end

  def delete_old_draft_on_update?
    @delete_old_draft_on_update ||= false
  end

  def validate_csv_errors
    @csv_errors ||= []
    @csv_errors.each do |e|
      errors.add(:items_from_csv, e)
    end
  end

  def delete_old_draft_if_necessary
    draft_items.destroy_all if @delete_old_draft_on_update
    @delete_old_draft_on_update = false
    return true
  end
end

