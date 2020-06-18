class LicenseGroup < ApplicationRecord
  has_and_belongs_to_many :licenses
  has_and_belongs_to_many :included, class_name: "LicenseGroup", foreign_key: "this_id", association_foreign_key: "includes_id", join_table: "license_group_includes"

  class << self
    def no_copyright
      self.find_by_key!("no_copyright")  
    end
  end

  def label
    I18n.t("license_group.labels.#{key}")
  end

  def all_ids_for_filter
    ids = [id]
    ids.concat(included.pluck(:id))
  end
end
