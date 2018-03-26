class HomePageFeed < ActiveRecord::Base
  validates_presence_of :name
  validate :validate_field_mask

  # XXX: don't ever change the order of these. Append only.
  FIELDS = [:img_url, :field_url, :label, :desc]

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
