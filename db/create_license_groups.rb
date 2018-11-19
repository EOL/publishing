def build_relationships(group, uris)
  licenses = License.where(source_url: uris)
  licenses.each do |license|
    license.license_groups << group
    license.save
  end
end

cc_by_nc_sa = LicenseGroup.find_or_create_by!({
  key: 'cc_by_nc_sa'
})
no_known = LicenseGroup.find_or_create_by!({
  key: 'no_known'
})
cc_by_nc = LicenseGroup.find_or_create_by!({
  key: 'cc_by_nc'
})
cc_by_sa = LicenseGroup.find_or_create_by!({
  key: 'cc_by_sa'
})
cc_by = LicenseGroup.find_or_create_by!({
  key: 'cc_by'
})

cc_by_nc_sa_uris = [
  'http://creativecommons.org/licenses/by-nc-sa/1.0/',
  'http://creativecommons.org/licenses/by-nc-sa/2.0/',
  'http://creativecommons.org/licenses/by-nc-sa/2.5/',
  'http://creativecommons.org/licenses/by-nc-sa/3.0/',
  'http://creativecommons.org/licenses/by-nc-sa/4.0/',
  'http://creativecommons.org/licenses/by-sa/1.0/',
  'http://creativecommons.org/licenses/by-sa/2.0/',
  'http://creativecommons.org/licenses/by-sa/2.5/',
  'http://creativecommons.org/licenses/by-sa/3.0/',
  'http://creativecommons.org/licenses/by-sa/4.0/',
  'http://creativecommons.org/licenses/by-nc/1.0/',
  'http://creativecommons.org/licenses/by-nc/2.0/',
  'http://creativecommons.org/licenses/by-nc/2.5/',
  'http://creativecommons.org/licenses/by-nc/3.0/',
  'http://creativecommons.org/licenses/by-nc/4.0/',
  'http://creativecommons.org/licenses/by/1.0/',
  'http://creativecommons.org/licenses/by/2.0/',
  'http://creativecommons.org/licenses/by/2.5/',
  'http://creativecommons.org/licenses/by/3.0/',
  'http://creativecommons.org/licenses/by/4.0/',
  'https://creativecommons.org/publicdomain/mark/1.0/',
  'https://creativecommons.org/publicdomain/zero/1.0/',
  'https://www.flickr.com/commons/usage'
]

no_known_uris = [
  'https://creativecommons.org/publicdomain/mark/1.0/',
  'https://creativecommons.org/publicdomain/zero/1.0/',
  'https://www.flickr.com/commons/usage'
]

cc_by_nc_uris = [
	'http://creativecommons.org/licenses/by-nc/1.0/',
	'http://creativecommons.org/licenses/by-nc/2.0/',
	'http://creativecommons.org/licenses/by-nc/2.5/',
	'http://creativecommons.org/licenses/by-nc/3.0/',
	'http://creativecommons.org/licenses/by-nc/4.0/',
	'http://creativecommons.org/licenses/by/1.0/',
	'http://creativecommons.org/licenses/by/2.0/',
	'http://creativecommons.org/licenses/by/2.5/',
	'http://creativecommons.org/licenses/by/3.0/',
	'http://creativecommons.org/licenses/by/4.0/',
	'https://creativecommons.org/publicdomain/mark/1.0/',
	'https://creativecommons.org/publicdomain/zero/1.0/',
	'https://www.flickr.com/commons/usage',
]

cc_by_sa_uris = [
	'http://creativecommons.org/licenses/by-sa/1.0/',
	'http://creativecommons.org/licenses/by-sa/2.0/',
	'http://creativecommons.org/licenses/by-sa/2.5/',
	'http://creativecommons.org/licenses/by-sa/3.0/',
	'http://creativecommons.org/licenses/by-sa/4.0/',
	'http://creativecommons.org/licenses/by/1.0/',
	'http://creativecommons.org/licenses/by/2.0/',
	'http://creativecommons.org/licenses/by/2.5/',
	'http://creativecommons.org/licenses/by/3.0/',
	'http://creativecommons.org/licenses/by/4.0/',
	'https://creativecommons.org/publicdomain/mark/1.0/',
	'https://creativecommons.org/publicdomain/zero/1.0/',
	'https://www.flickr.com/commons/usage',
]

cc_by_uris = [
	'http://creativecommons.org/licenses/by/1.0/',
	'http://creativecommons.org/licenses/by/2.0/',
	'http://creativecommons.org/licenses/by/2.5/',
	'http://creativecommons.org/licenses/by/3.0/',
	'http://creativecommons.org/licenses/by/4.0/',
	'https://creativecommons.org/publicdomain/mark/1.0/',
	'https://creativecommons.org/publicdomain/zero/1.0/',
	'https://www.flickr.com/commons/usage'
]

build_relationships(cc_by_nc_sa, cc_by_nc_sa_uris)
build_relationships(no_known, no_known_uris)
build_relationships(cc_by_sa, cc_by_sa_uris)
build_relationships(cc_by, cc_by_uris)

