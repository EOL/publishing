module Publishing::GetsLicenses
  def get_license(url)
    @licenses ||= {}
    if url.blank?
      return @resource.default_license&.id || License.public_domain.id
    end
    return @licenses[url] if @licenses.key?(url)
    if (license = License.find_by_source_url(url))
      return @licenses[url] = license.id
    end
    name =
      if url =~ /creativecommons.*\/licenses/
        "cc-" + url.split('/')[-2]
      else
        url.split('/').last.titleize
      end
    license = License.create(name: name, source_url: url, can_be_chosen_by_partners: false)
    @licenses[url] = license.id
  end
end
