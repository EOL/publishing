# Reindex the pages in a resumable way.
class Page::Reindexer
  # NOTE: There were instance methods here to *manually* reindex things and "watch" the progress. I've removed them. If
  # you want to see them again, checkout 69b3076fa15c880daff673a45e073eb22d026371
  class << self
    def reindex
      setup_background
      Page.reindex(async: {wait: true})
    end

    # Simply Page::Reindexer.resume_reindex
    def resume_reindex
      setup_background
      Page.reindex(async: {wait: true}, resume: true)
    end

    def background_reindex
      path = Rails.root.join('log', 'es_page_reindex.log')
      `nohup rails r 'Page.reindex(async: {wait: true}, resume: true)' > #{path} 2>&1 &`
    end

    def promote_background_index(force = false)
      status = Searchkick.reindex_status(index_names.sort.last)
      if !force && !status[:completed]
        puts "Reindex incomplete! There are #{status[:batches_left]} batches left.\n"\
             "You can override this with \`promote_background_index(true)\`."
        return
      end
      Product.search_index.promote(index_names.sort.last)
      # => {:completed=>false, :batches_left=>2143}
    end

    def index_names
      Page.searchkick_index.all_indices
    end

    def setup_background
      @redis ||= Redis.new(host: "redis")
      Searchkick.redis = @redis
    end

    # NOTE: the rest of these class methods are indended for informational use by a developer or sysops. Please keep,
    # even though the code may not reference them.
    def index_name
      Page.searchkick_index.settings.keys.first
    end

    def refresh_interval=(time)
      Page.search_index.update_settings(index: { refresh_interval: time })
    end

    # This is not kosher; they don't want us to access the client directly, so they can control the index name (at
    # least).
    def client
      @client ||= Page.searchkick_index.send :client
    end

    def index_sizes
      results = {}
      index_names.each do |name|
        response =
          client.search(
            index: name,
            body: { query: { match_all: {} }, size: 0 }
          )
        results[name] = Searchkick::Results.new(nil, response).total_count
      end
      results
    end
  end
end
