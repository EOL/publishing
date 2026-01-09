# TODO: Rename this to HarvestingServerConnection to be consistent with naming
module ContentServer
  class NotFoundError < StandardError # 404
  end

  class BadGatewayEerror < StandardError # 502 Bad Gateway
  end
end

class ContentServerConnection
  TRAIT_DIFF_SLEEP = 10
  MAX_TRAIT_DIFF_TRIES = 60 # * 10s = 30 = 300s = 5 mins

  def initialize(resource, log = nil)
    @resource = resource
    harv_url = Rails.configuration.creds[:repository][:url]
    @harv_site = URI(harv_url)
    @log = log # Okay if it's nil.
    @unacceptable_codes = 300
    @trait_diff_tries = 0
  end

  def file_url(name)
    "/data/#{@resource.path}/publish_#{name}"
  end
  
  def exists?(name)
    File.exist?(file_path(name))
  end
  
  def file(name)
    return false unless exists?(name)
    get_contents(file_path(name))
  end
  
  def trait_diff_metadata
    @trait_diff_tries = 0
    trait_diff_metadata_helper
  end
  
  def copy_file(local_name, remote_name)
    open(local_name, 'wb') { |f| f.write(file(remote_name)) }
  end
  
  def copy_harvesting_file(local_path, remote_path)
    # We used to read these from a remote path, but now we read them from an NFS mount, convert:
    nfs_path = remote_path.sub(%r{^/data}, '/app/harvesting/')
    return unless File.exist?(nfs_path)
    File.open(local_path, 'wb') do |out_file|
      File.foreach(nfs_path) do |line|
        # Process and write one line at a time
        out_file.write(fix_neo4j_illegal_quotes(line))
      end
    end
  end

  private

  # This method can receive two different formats. One is something like "traits.tsv" and the other is a "relative path".
  # The latter will always have a slash in it, so we check for that, then handle the result:
  def file_path(name)
    name =~ %r{/} ?
      name.sub(%r{^/data/}, '/app/harvesting/') :
      "/app/harvesting/#{@resource.path}/publish_#{name}"
  end
  
  def is_on_this_host?
    @harv_is_on_this_host ||= (@harv_site.host == '128.0.0.1' ||  @harv_site.host == 'localhost')
  end
  
  # NOTE: don't rename this to "contents" ... there are variables with that name
  def get_contents(file)
    file_contents_to_clean_string(file)
  end

  def file_contents_to_clean_string(local_file)
    contents = File.readlines(local_file)
    contents.each do |line|
      line = fix_neo4j_illegal_quotes(line)
    end
    contents.join
  end

  def fix_neo4j_illegal_quotes(string)
    string.gsub(/\\\n/, "\n").gsub(/\\N/, '').gsub(/""/, '\\"')
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
      # Example:
      # { "status":"completed","new_traits_path":"/data/dhvdd/publish_traits.tsv",
      #   "removed_traits_path":null,"new_metadata_path":"/data/dhvdd/publish_metadata.tsv","remove_all_traits":true }
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
      @connection.copy_harvesting_file(local, remote) unless local.nil?
    end
  end

  private
  def trait_diff_metadata_helper
    url = "/resources/#{@resource.repository_id}/publish_diffs.json"
    url += "?since=#{@resource.last_published_at.to_i}" unless @resource.last_published_at.nil?

    log_info("polling for trait diff metadata: #{url}") if @trait_diff_tries.zero?

    resp = nil

    Net::HTTP.start(@harv_site.host, @harv_site.port, use_ssl: @harv_site.scheme == 'https') do |http|
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
