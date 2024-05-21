class SearchController < ApplicationController
  include HasAutocomplete
  MAX_AUTOCOMPLETE_RESULTS = 10

  before_action :no_main_container

  def index
    @suppress_search_icon = true
  end

  def search
    if params[:q].present?
      do_search
    end
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
    # TEMP: term_results = TermNode.autocomplete(params[:query], common_options)
    pages_simple = autocomplete_results(pages_results, "pages")
    # TEMP: terms_simple = autocomplete_results(term_results, "term_nodes")
    # TEMP: render json: (pages_simple.concat(terms_simple).sort do |a, b|
    render json: (pages_simple.sort do |a, b|
      a[:name].length <=> b[:name].length
    end)[0, MAX_AUTOCOMPLETE_RESULTS]
  end

private
  def do_search
    searcher = MultiClassSearch.new(params[:q], params)
    @page = params[:page]&.to_i
    @q = searcher.query # get a clean version of the search string for re-use in the form

    path = searcher.suggested_path?
    flash[:notice] = searcher.notice if searcher.notice
    return redirect_to(path) if path

    searcher.search
    if searcher.errors.any?
      logger.error("Search errors: #{searcher.errors.join('; ')}")
      raise "search failed"
    end

    @pages = searcher.pages
    @articles = searcher.articles
    @users = searcher.users
    @terms = searcher.terms

    respond_to do |fmt|
      fmt.html do
        @page_title = t(:page_title_search, query: @q)
      end
      # TODO: JSON. This has been broken since Feb 27, 2020, so look at code from before that if you want to make
      # another attempt.
      fmt.js { }
    end
  end
end
