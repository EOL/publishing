# TODO: we should NOT need to definte this. It should be in the gem. I'm just
# following a guide, here, though, and it may be older than the current version,
# so it COULD be there; check.
class SolrService
  @@connection = false

  def self.connect
    # TODO: uhhh... shouldn't this use the config? (config/blacklight.yml)
    @@connection = RSolr.connect(url: "http://localhost:8983/solr/eol_website")
    @@connection
  end

  def self.add(params)
    connect unless @@connection
    @@connection.add(params)
  end

  def self.commit
    connect unless @@connection
    @@connection.commit
  end

  def self.delete_by_id(id)
    connect unless @@connection
    @@connection.delete_by_id(id)
  end
end
