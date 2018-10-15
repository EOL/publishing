class Repository
  def initialize(resource, log = nil)
    @resource = resource
    repo_url = Rails.application.secrets.repository['url']
    @repo_site = URI(repo_url)
    @log = log # Okay if it's nil.
  end

  def is_on_this_host?
    @repo_is_on_this_host ||= repo_url.match(/(128\.0\.0\.1|localhost)/)
  end

  def file_url(name)
    "/data/#{@resource.path}/publish_#{name}"
  end

  def exists?(name)
    url = URI.parse(file_url(name))
    req = Net::HTTP.new(@repo_site.host, @repo_site.port)
    res = req.request_head(url.path)
    res.code.to_i < 400
  end

  def copy_file(local_name, remote_name)
    open(local_name, 'wb') { |f| f.write(file(remote_name)) }
  end

  def file(name)
    url = file_url(name)
    resp = nil
    result = Net::HTTP.start(@repo_site.host, @repo_site.port) do |http|
      resp = http.get(url)
    end
    unless result.code.to_i < 400
      log_warn("MISSING #{@repo_site}#{url} [#{result.code}] (#{resp.size} bytes); skipping")
      return false
    end
    resp.body
  end

  def log_warn(what)
    if @log.respond_to?(:log)
      @log.log(what.to_s, cat: :warns)
    else
      puts "!! WARNING: #{what}"
    end
  end
end
