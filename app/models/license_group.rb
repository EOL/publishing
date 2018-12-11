class LicenseGroup < ActiveRecord::Base
  has_and_belongs_to_many :licenses

  def label
    I18n.t("license_group.labels.#{key}")
  end
end
