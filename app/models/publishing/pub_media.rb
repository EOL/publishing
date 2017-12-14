class Publishing::PubMedia
  include Publishing::GetsLanguages
  include Publishing::GetsLicenses

  def self.import(resource, log, repo)
    Publishing::PubMedia.new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
    @media_by_page = {}
    @media_pks = []
    @media_id_by_pk = {}
    @contents = []
    @ancestry = {}
    @naked_pages = {}
  end

  # TODO: set these:
  # t.datetime :last_published_at
  # t.integer :last_publish_seconds
  def import
    @log.log('import_media')
    @image_info = []
    count = @repo.get_new(Medium) do |medium|
      debugger if medium[:subclass] != 'image' # TODO
      debugger if medium[:format] != 'jpg' # TODO
      sizes = medium.delete(:sizes)
      begin
        hash = JSON.parse(sizes)
        @image_info <<
          { resource_id: @resource_id, resource_pk: medium[:resource_pk], original_size: hash['original'],
            large_size: hash['580x360'], medium_size: hash['260x190'], small_size: hash['98x68'] }
      rescue => e
        # I don't care... TODO: maybe you should.
      end
      # TODO: locations import
      # TODO: bibliographic_citations import
      lang = medium.delete(:language)
      # TODO: default language per resource?
      medium[:language_id] = lang ? get_language(lang) : get_language(code: "eng", group_code: "en")
      license_url = medium.delete(:license)
      medium[:license_id] = get_license(license_url)
      medium[:base_url] = "#{Rails.configuration.repository_url}/#{medium[:base_url]}" unless
        medium[:base_url] =~ /^http/
      @media_by_page[medium[:page_id]] = medium[:resource_pk]
      if medium[:page_id].blank?
        @log.log("Medium {#{medium[:resource_pk]}} skipped: missing page_id——perhaps node is missing?")
        next
      end
      @media_pks << medium[:resource_pk]
    end
    return if count.zero?
    MediaContentCreator.by_resource(@resource, @log)
    unless @image_info.empty?
      @log.log("Importing #{@image_info.size} image info records...")
      ImageInfo.import!(@image_info, on_duplicate_key_ignore: true)
      ImageInfo.propagate_id(fk: 'resource_pk', other: 'medium.resource_pk', set: 'medium_id', with: 'id',
                             resource_id: @resource.id)
    end
  end
end
