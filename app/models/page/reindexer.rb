# Reindex the pages in a resumable way.
# nohup rails r "Page::Reindexer.reindex" > log/reindex.log 2>&1 &
# OR (for JUST pages, the log will go to /app/log/es_page_reindex.log automatically)
# rails r "Page::Reindexer.background_reindex_pages"
class Page::Reindexer
  # NOTE: There were instance methods here to *manually* reindex things and "watch" the progress. I've removed them. If
  # you want to see them again, checkout 69b3076fa15c880daff673a45e073eb22d026371
  class << self
    def reindex
      # TODO: Not an AR model, so not working with new version of Searchkick!
      # TermNode.reindex # This one MUST run in the foreground, because it's not a AR model.
      # These are super fast, not worth putting in the background.
      Resource.reindex
      User.reindex
      SearchSuggestion.reindex
      # These are not so fast:
      Article.reindex
      # This one is a beast, so we should background it:
      Medium.reindex(async: true, resume: true, refresh_interval: '60s')
      background_reindex_pages
    end

    # Simply Page::Reindexer.resume_reindex
    def resume_reindex
      Page.reindex(async: true, resume: true, refresh_interval: '60s')
    end

    def background_reindex_pages
      path = Rails.root.join('log', 'es_page_reindex.log')
      cmd = 'Page.reindex(async: {wait: true}, resume: true)'
      rescue_cmd = 'Page.reindex(async: true, refresh_interval: "60s")'
      `nohup rails r '#{cmd} rescue #{rescue_cmd}' > #{path} 2>&1 &`
    end

    def promote_background_index(force = false)
      # => {:completed=>false, :batches_left=>2143}
      status = Searchkick.reindex_status(index_names.sort.last)
      if !force && !status[:completed]
        puts "Reindex incomplete! There are #{status[:batches_left]} batches left.\n"\
             "You can override this with \`promote_background_index(true)\`."
        return
      end
      Page.search_index.promote(index_names.sort.last, update_refresh_interval: true)
    end

    # puts Searchkick.client.cat.indices
    #
    # You may also need something like:
    # Page.search_index.promote('pages_staging_20200727174956767')
    def index_names
      Page.searchkick_index.all_indices
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
