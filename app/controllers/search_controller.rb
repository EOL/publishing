class SearchController < ApplicationController
  include HasAutocomplete
  MAX_AUTOCOMPLETE_RESULTS = 10

  before_action :no_main_container

  def index
    @suppress_search_icon = true
  end

  def search
    do_search
  end

  def search_page
    @type = params[:only].to_sym
    do_search
    render :layout => false
  end

  def autocomplete
    common_options = {
      limit: MAX_AUTOCOMPLETE_RESULTS,
    }

    pages_results = Page.autocomplete(params[:query], common_options)
    term_results = TermNode.autocomplete(params[:query], common_options)
    pages_simple = autocomplete_results(pages_results, "pages")
    terms_simple = autocomplete_results(term_results, "term_nodes")
    render json: (pages_simple.concat(terms_simple).sort do |a, b|
      a[:name].length <=> b[:name].length 
    end)[0, MAX_AUTOCOMPLETE_RESULTS]
  end

private
  def do_search
    searcher = MultiClassSearch.new(params[:q], params)
    @q = searcher.query # get a clean version of the search string for re-use in the form

    path = searcher.suggested_path?
    flash[:notice] = searcher.notice if searcher.notice
    return redirect_to(path) if path

    searcher.search
    if searcher.errors.any?
      logger.error("Search errors: #{searcher.errors.join("; ")}")
      raise "search failed"
    end

    @pages = searcher.pages
    @articles = searcher.articles
    @collections = searcher.collections
    @users = searcher.users
    @terms = searcher.terms

    respond_to do |fmt|
      fmt.html do
        @page_title = t(:page_title_search, query: @q)
      end

      fmt.js { }

      # TODO: JSON results for other types! TODO: move; this is view logic...
      # This is broken as of 2/27/20 (probably much earlier). Commenting out in case we want it later - mvitale
     # fmt.json do
     #   render json: JSON.pretty_generate(@pages.results.as_json(
     #     except: :native_node_id,
     #     methods: :scientific_name,
     #     include: {
     #       preferred_vernaculars: { only: [:string],
     #         include: { language: { only: :code } } },
     #       # NOTE I'm excluding a lot more for search than you would want for
     #       # the basic page json:
     #       top_media: { only: [ :id, :guid, :owner, :name ],
     #         methods: [:small_icon_url, :medium_icon_url],
     #         include: { provider: { only: [:id, :name] },
     #           license: { only: [:id, :name, :icon_url] } } }
     #     }
     #   ))
     # end
    end
  end
end
