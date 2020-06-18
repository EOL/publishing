class SearchController < ApplicationController
  before_action :no_main_container

  MAX_AUTOCOMPLETE_RESULTS = 10

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
    pages_simple = suggest_results(pages_results, "pages")
    terms_simple = suggest_results(term_results, "term_nodes")
    render json: pages_simple.concat(terms_simple)[0, MAX_AUTOCOMPLETE_RESULTS]
  end

private
  # TODO: remove, just here for reference as we move to suggest_results
  #def simple_results(full_results, default_name_field, query, controller)
  #  result_hash = {}
  #  full_results.each do |r|
  #    field = r['highlight']&.first&.first&.split('.').first
  #    name = r.send(field) || r.send(default_name_field)
  #    if name.is_a?(Array)
  #      first_hit = name.grep(/#{query}/i)&.first
  #      name = first_hit || name.first
  #    end
  #    result_hash[name] =
  #      if result_hash.key?(name)
  #        new_string = params[:no_multiple_text] ? name : "#{name} (multiple hits)"
  #        { name: new_string, title: new_string, id: r.id, url: search_path(q: name, utf8: true) }
  #      else
  #        { name: name, title: name, id: r.id, url: url_for(controller: controller, action: "show", id: r.id) }
  #      end
  #  end
  #  result_hash.values
  #end

  def suggest_results(sk_result, controller)
    result_hash = {}

    sk_result.response["suggest"]["autocomplete"].first["options"].each do |r|
      text = r["text"]
      id = r["_id"]

      if result_hash.key?(text)
        name = params[:no_multiple_text] ? text : "#{text} (multiple hits)"
        url = search_path(q: text, utf8: true)
      else
        name = text
        url = url_for(controller: controller, action: "show", id: id)
      end

      result_hash[text] = { 
        name: name, 
        title: name, 
        id: id, 
        url: url
      }
    end

    result_hash.values
  end

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
