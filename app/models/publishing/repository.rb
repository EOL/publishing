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
      next unless thing
      thing.merge!(resource_id: @resource.id)
      begin
        yield(thing)
        things << thing
        total_count += 1
      rescue => e
        @log.log("FAILED to add #{klass.class_name.downcase}: #{e.message}", cat: :errors)
        @log.log("MISSING #{klass.class_name.downcase}: #{thing.inspect}", cat: :errors)
      end
      things = flush_things(klass, things) if things.size >= 10_000
    end
    flush_things(klass, things)
    if total_count.zero?
      @log.log("There were NO new #{klass.name.pluralize.downcase}, skipping...", cat: :warns)
    else
      @log.log("Total #{klass.name.pluralize} Published: #{total_count}")
    end
    total_count
  end

  def flush_things(klass, things)
    @log.log("importing #{things.size} #{klass.name.pluralize}")
    # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when
    # I want to ignore the ones we already had (I would delete things first if I wanted to replace them):
    klass.import(things, on_duplicate_key_ignore: true, validate: false)
    []
  end

  # TODO: I would love to extract enough here to be able to call something like
  # get_page(path, key, page)
  def loop_over_pages(path_without_page, key)
    page = 1
    total_pages = 2 # Dones't matter YET... will be populated in a bit...
    while page <= total_pages
      response = get_response_safely(key, page, path_without_page)
      next unless response.is_a?(Hash) && response.key?("totalPages")
      total_pages = response["totalPages"]
      report_on_import(key, page, total_pages)
      response[key].each do |data|
        thing = Publishing::Repository.underscore_hash_keys(data)
        yield(thing)
      end
      page += 1
    end
  end

  def report_on_import(key, page, total_pages)
    return unless page == 1 || (page % 25).zero?
    pct = (page / total_pages.to_f * 100).ceil rescue '??'
    @log.log("Importing #{key.pluralize}: page #{page}/#{total_pages} (#{pct}%)", cat: :infos)
  end

  def get_response_safely(key, page, path_without_page)
    url = "#{Rails.configuration.repository_url}/#{path_without_page}page=#{page}"
    url += "&since=#{@since}" if @since
    tries ||= 3
    html_response = Net::HTTP.get_response(URI.parse(url))
    # Raise error if not success (poorly named method)
    html_response.value
    response = JSON.parse(html_response.body)
    return response if response.key?(key)
    @log.log("Empty #{key}: #{url}", cat: :infos)
    nil
  rescue => e
    tries -= 1
    @log.log("!! Failed to read #{key} page #{page}! url: #{url} message: #{e.message[0..100]}", cat: :errors)
    log_parsed_result(response)
    retry if tries.positive?
    @log.log("!! FAILURE: exceeded retry count.", cat: :errors)
    raise e # JRice changed this from "nil" on Jul 2019 because it was causing a log overflow.
  end

  def log_parsed_result(response)
    noko = Nokogiri.parse(response) rescue nil
    return unless noko
    @log.log(noko.css('html head title')&.text)
    @log.log(noko.css('html body h1')&.text)
    @log.log(noko.css('html body p')&.map { |p| p.text }.join("; "))
  end
end
