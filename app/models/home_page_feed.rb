require "csv"
require "set"

class HomePageFeed < ApplicationRecord
  validates :name, :presence => true, :uniqueness => true
  validate :validate_field_mask
  validate :validate_tsv_errors

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
    @fields = nil
    self.field_mask = fields.reject{ |f| f.blank? }.map { |f| 2**FIELDS[f.to_sym] }.inject(0, :+)
  end

  def fields
    @fields ||= FIELDS.keys.reject do |f|
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

  def items_from_tsv=(tsv_file)
    @tsv_errors = []

    begin
      raise "must specify a file" if !tsv_file

      tsv_str = tsv_file.read
      tsv = CSV.parse(tsv_str, headers: true, col_sep: "\t")
      headers_sym = tsv.headers.collect { |h| h.to_sym }
      field_set = Set.new(fields)

      raise "can't be blank" if !tsv.any?

      headers_sym.each do |h|
        if !field_set.include? h
          raise "invalid column header: #{h}"
        end
      end

      self.items_attributes = tsv.collect(&:to_h)
      @delete_old_draft_on_update = true
    rescue => e
      @tsv_errors << e.message
    end 
  end

  def cur_draft_items_tsv
    CSV.generate(col_sep: "\t") do |csv|
      csv << fields

      draft_items.each do |item|
        csv << fields.collect do |field|
          item.attributes[field.to_s] 
        end
      end
    end
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

  def validate_tsv_errors
    @tsv_errors ||= []
    @tsv_errors.each do |e|
      errors.add(:items_from_tsv, e)
    end
  end

  def delete_old_draft_if_necessary
    draft_items.destroy_all if @delete_old_draft_on_update
    @delete_old_draft_on_update = false
    return true
  end
end

