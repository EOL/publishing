# WARNING: This program deletes all existing LicenseGroups before building LicenseGroups and associations. LicenseGroup data changes should therefore only be made in this file, not ad hoc.
def build_relationships(group, uris)
  licenses = License.where(source_url: uris)
  group.licenses = licenses
end

LicenseGroup.delete_all
cc_by_nc_sa = LicenseGroup.create!({
  key: 'cc_by_nc_sa'
})
cc_by_nc = LicenseGroup.create!({
  key: 'cc_by_nc'
})
cc_by_sa = LicenseGroup.create!({
  key: 'cc_by_sa'
})
cc_by = LicenseGroup.create!({
  key: 'cc_by'
})
no_copyright = LicenseGroup.create!({
  key: 'no_copyright'
})

cc_by_nc_sa.included = [cc_by_nc, cc_by_sa, cc_by, no_copyright]
cc_by_nc.included = [cc_by, no_copyright]
cc_by_sa.included = [cc_by, no_copyright]
cc_by.included = [no_copyright]


cc_by_nc_sa_uris = [
  'http://creativecommons.org/licenses/by-nc-sa/1.0/',
  'http://creativecommons.org/licenses/by-nc-sa/2.0/',
  'http://creativecommons.org/licenses/by-nc-sa/2.5/',
  'http://creativecommons.org/licenses/by-nc-sa/3.0/',
  'http://creativecommons.org/licenses/by-nc-sa/4.0/',
]

cc_by_nc_uris = [
	'http://creativecommons.org/licenses/by-nc/1.0/',
	'http://creativecommons.org/licenses/by-nc/2.0/',
	'http://creativecommons.org/licenses/by-nc/2.5/',
	'http://creativecommons.org/licenses/by-nc/3.0/',
	'http://creativecommons.org/licenses/by-nc/4.0/',
]

cc_by_sa_uris = [
	'http://creativecommons.org/licenses/by-sa/1.0/',
	'http://creativecommons.org/licenses/by-sa/2.0/',
	'http://creativecommons.org/licenses/by-sa/2.5/',
	'http://creativecommons.org/licenses/by-sa/3.0/',
	'http://creativecommons.org/licenses/by-sa/4.0/',
]

cc_by_uris = [
	'http://creativecommons.org/licenses/by/1.0/',
	'http://creativecommons.org/licenses/by/2.0/',
	'http://creativecommons.org/licenses/by/2.5/',
	'http://creativecommons.org/licenses/by/3.0/',
	'http://creativecommons.org/licenses/by/4.0/',
]

no_copyright_uris = [
  "https://creativecommons.org/publicdomain/",
  "http://creativecommons.org/licenses/publicdomain/",
  "No known copyright restrictions",
  "http://www.flickr.com/commons/usage/",
  "http://creativecommons.org/publicdomain/zero/1.0/",
  "http://creativecommons.org/licenses/publicdomain/3.0/"
]

build_relationships(cc_by_nc_sa, cc_by_nc_sa_uris)
build_relationships(cc_by_nc, cc_by_nc_uris)
build_relationships(cc_by_sa, cc_by_sa_uris)
build_relationships(cc_by, cc_by_uris)
build_relationships(no_copyright, no_copyright_uris)

cc_by_nc_sa.save!
cc_by_nc.save!
cc_by_sa.save!
cc_by.save!
no_copyright.save!

