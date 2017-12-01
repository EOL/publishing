class Publishing::Repository
  attr_accessor :resource, :log, :since

  def self.underscore_hash_keys(hash)
    new_hash = {}
    hash.each do |k, v|
      val = v.is_a?(Hash) ? Publishing::Repository.underscore_hash_keys(v) : v
      new_hash[k.underscore.to_sym] = val
    end
    new_hash
  end

  def initialize(options = {})
    @resource = options[:resource] # NOTE: can be nil!
    @log = options[:log] || Publishing::PubLog.new(nil)
    @since = options[:since]
  end

  def get_new(klass)
    type = klass.class_name.underscore.pluralize.downcase
    total_count = 0
    things = []
    path = "resources/#{@resource.repository_id}/#{type}.json?"
    loop_over_pages(path, type.camelize(:lower)) do |thing|
      thing.merge!(resource_id: @resource.id)
      if thing
        begin
          yield(thing)
          things << thing
          total_count += 1
        rescue => e
          @log.log("FAILED to add #{klass.class_name.downcase}: #{e.message}", cat: :errors)
          @log.log("MISSING #{klass.class_name.downcase}: #{thing.inspect}", cat: :errors)
        end
      end
      if things.size >= 10_000
        @log.log("importing #{things.size} #{klass.name.pluralize}")
        # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when
        # I want to ignore the ones we already had (I would delete things first if I wanted to replace them):
        klass.import(things, on_duplicate_key_ignore: true, validate: false)
        things = []
      end
    end
    if things.any?
      @log.log("importing #{things.size} #{klass.name.pluralize}")
      klass.import(things, on_duplicate_key_ignore: true, validate: false)
    end
    if total_count.zero?
      @log.log("There were NO new #{klass.name.pluralize.downcase}, skipping...", cat: :warns)
    else
      @log.log("Total #{klass.name.pluralize} Published: #{total_count}")
    end
    total_count
  end

  def loop_over_pages(path_without_page, key)
    page = 1
    total_pages = 2 # Dones't matter YET... will be populated in a bit...
    while page <= total_pages
      url = "#{Rails.configuration.repository_url}/#{path_without_page}page=#{page}"
      url += "&since=#{@since}" if @since
      html_response = Net::HTTP.get(URI.parse(url))
      begin
        response = JSON.parse(html_response)
      rescue => e
        @log.log("!! Failed to read #{key} page #{page}! url: #{url}", cat: :errors)
        noko = Nokogiri.parse(response)
        @log.log(noko.css('html head title')&.text)
        @log.log(noko.css('html body h1')&.text)
        @log.log(noko.css('html body p')&.map { |p| p.text }.join("; "))
        debugger if Rails.env.development?
        return
      end
      total_pages = response["totalPages"]
      return unless response.key?(key) && total_pages.positive? # Nothing returned, otherwise.
      if page == 1 || (page % 25).zero?
        pct = (page / total_pages.to_f * 100).ceil rescue '??'
        @log.log("Importing #{key.pluralize}: page #{page}/#{total_pages} (#{pct}%)", cat: :infos)
      end
      response[key].each do |data|
        thing = Publishing::Repository.underscore_hash_keys(data)
        yield(thing)
      end
      page += 1
    end
  end
end
