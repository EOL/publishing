# TODO: Rename this to HarvestingServerConnection to be consistent with naming
class ContentServerConnection
  TRAIT_DIFF_SLEEP = 10
  MAX_TRAIT_DIFF_TRIES = 60 # * 10s = 30 = 300s = 5 mins

  def initialize(resource, log = nil)
    @resource = resource
    repo_url = Rails.configuration.creds[:repository][:url]
    @repo_site = URI(repo_url)
    @log = log # Okay if it's nil.
    @unacceptable_codes = 300
    @trait_diff_tries = 0
  end

  def is_on_this_host?
    @repo_is_on_this_host ||= (@repo_site.host == '128.0.0.1' ||  @repo_site.host == 'localhost')
  end

  def file_url(name)
    "/data/#{@resource.path}/publish_#{name}"
  end

  def exists?(name)
    url = URI.parse(file_url(name)) # e.g.: "/data/NMNHtypes/publish_publish_metadata.tsv"
    req = Net::HTTP.new(@repo_site.host, @repo_site.port)
    req.use_ssl = @repo_site.scheme == 'https'
    res = req.request_head(url.path)
    res.code.to_i < @unacceptable_codes
  end

  def copy_file(local_name, remote_name)
    open(local_name, 'wb') { |f| f.write(file(remote_name)) }
  end

  def copy_file_for_remote_url(local_path, remote_url)
    open(local_path, 'wb') { |f| f.write(contents_from_url(remote_url)) }
  end

  def file(name)
    contents_from_url(file_url(name))
  end
  
  def contents_from_url(url)
    attempts = 0
    do
      result = wget_file(url)
      attempts += 1
      raise "Unable to connect to harvesting website" if attempts >= 3
      break unless result =~ /Bad Gateway/
      log_info("BAD GATEWAY ... trying again (attempt #{attempts})")
    end
    # Need to get the _harvester_session cookie or this will not work:
    uri = URI.parse(Rails.configuration.creds[:repository][:url] + '/')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    log_info("Connecting to #{uri} ...")
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    cookies = response.response['set-cookie']
    request = Net::HTTP::Get.new(url)
    request['Cookie'] = cookies
    response = http.request(request)
    if response.code.to_i >= @unacceptable_codes
      log_warn("MISSING #{@repo_site}#{url} [#{response.code}] (#{response.size} bytes); skipping")
      return false
    elsif response.body.size < response.content_length - 1
      log_warn("TRUNCATED RESPONSE! Got #{response.body.size} bytes out of #{response.content_length} from #{@repo_site}#{url}")
      return wget_file(url)
    end
    # NOTE: neo4j cannot properly handle all cases of meta-quoted double quotes ("") so we change them here
    # to backslashed quotes (\"). This is not the greatest place to do it, as we've obfuscated the transofmration,
    # but it would be less efficient elsewhere.
    fix_neo4j_illegal_quotes(response.body)
  end

  def wget_file(url)
    log_warn('USING wget TO RETRIEVE FULL FILE...')
    timestamp = Time.now.to_i
    local_file = Rails.root.join('tmp', "#{@resource.abbr}_tmp_#{timestamp}_#{File.basename(url)}")
    log_file = Rails.root.join('tmp', "#{@resource.abbr}_tmp_#{timestamp}.log")
    `wget -c -r -O #{local_file} -o #{log_file} #{@repo_site}#{url}`
    second_timestamp = Time.now.to_i
    log_warn("Took #{second_timestamp - timestamp} seconds.")
    last_line = log_wget_response(log_file)
    raise "ERROR CODE #{$?} using wget of #{url}" unless $?.zero?
    read_wget_output_to_string(local_file)
    return last_line
  end

  def log_wget_response(log_file)
    last_line = ''
    File.readlines(log_file).reject {|l| l =~ / .......... /}.reject {|l| l == "\n" }.each do |line|
      last_line = line if line =~ /\w/
      log_info(line)
    end
    File.unlink(log_file)
    return last_line
  end

  def read_wget_output_to_string(local_file)
    contents = File.readlines(local_file)
    contents.each do |line|
      line = fix_neo4j_illegal_quotes(line)
    end
    File.unlink(local_file)
    contents.join
  end

  def fix_neo4j_illegal_quotes(string)
    string.gsub(/\\\n/, "\n").gsub(/\\N/, '').gsub(/""/, '\\"')
  end

  def trait_diff_metadata
    @trait_diff_tries = 0
    trait_diff_metadata_helper
  end

  def log_info(what)
    if @log.respond_to?(:log)
      @log.log(what.to_s, cat: :infos)
    else
      puts what
    end
  end

  def log_warn(what)
    if @log.respond_to?(:log)
      @log.log(what.to_s, cat: :warns)
    else
      puts "!! WARNING: #{what}"
    end
  end

  class TraitDiffMetadata
    attr_reader :new_traits_file, :removed_traits_file, :new_metadata_file, :json, :resource, :connection

    def initialize(json, resource, connection)
      @json = json
      @resource = resource
      @connection = connection
      @remove_all_traits = json['remove_all_traits']

      copy_new_traits
      copy_remove_traits
      copy_new_metadata
    end

    def copy_new_traits
      new_traits_path_remote = @json['new_traits_path']
      new_traits_path = local_path(new_traits_path_remote)
      copy_trait_file(new_traits_path, new_traits_path_remote)
      @new_traits_file = new_traits_path.nil? ? nil : File.basename(new_traits_path)
    end

    def copy_remove_traits
      removed_traits_path_remote = @json['removed_traits_path']
      removed_traits_path = local_path(removed_traits_path_remote)
      copy_trait_file(removed_traits_path, removed_traits_path_remote)
      @removed_traits_file = removed_traits_path.nil? ? nil : File.basename(removed_traits_path)
    end

    def copy_new_metadata
      new_metadata_path_remote = @json['new_metadata_path']
      new_metadata_path = local_path(new_metadata_path_remote)
      copy_trait_file(new_metadata_path, new_metadata_path_remote)
      @new_metadata_file = new_metadata_path.nil? ? nil : File.basename(new_metadata_path)
    end

    def remove_all_traits?
      @remove_all_traits
    end

    private
    def local_path(remote_path)
      remote_path.nil? ?
        nil :
        @resource.ensure_file_dir.join(File.basename(remote_path))
    end

    def copy_trait_file(local, remote)
      @connection.copy_file_for_remote_url(local, remote) unless local.nil?
    end
  end

  private
  def trait_diff_metadata_helper
    url = "/resources/#{@resource.repository_id}/publish_diffs.json"
    url += "?since=#{@resource.last_published_at.to_i}" unless @resource.last_published_at.nil?

    log_info("polling for trait diff metadata: #{url}") if @trait_diff_tries.zero?

    resp = nil

    Net::HTTP.start(@repo_site.host, @repo_site.port, use_ssl: @repo_site.scheme == 'https') do |http|
      resp = http.get(url)
    end

    unless resp.is_a?(Net::HTTPSuccess)
      raise "Got unexpected response code from #{url}: #{resp.code}"
    end

    result = JSON.parse(resp.body)
    @trait_diff_tries += 1
    if @trait_diff_tries == MAX_TRAIT_DIFF_TRIES
      log_warn("Max trait diff tries (#{MAX_TRAIT_DIFF_TRIES}) reached; giving up. Response: #{result.to_s[0..6_000]}")
      return nil
    end

    return handle_trait_diff_metadata_resp(result)
  end

  def handle_trait_diff_metadata_resp(json)
    status = json['status']

    case status
    when 'completed'
      return TraitDiffMetadata.new(json, @resource, self)
    when 'pending', 'enqueued', 'processing'
      log_info("harvesting server processing results, waiting for completion... (attempt #{@trait_diff_tries}/#{MAX_TRAIT_DIFF_TRIES})")
      sleep 10
      return trait_diff_metadata_helper
    else
      raise "Got unexpected status from trait diff metadata request: #{status}"
    end
  end

end
