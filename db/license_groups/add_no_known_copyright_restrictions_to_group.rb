group = LicenseGroup.find_by(key: "no_known")
licenses = License.where(source_url: "No known copyright")
licenses.each do |license|
  group.licenses << license
end
