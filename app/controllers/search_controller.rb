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
      match: :text_start,
      limit: MAX_AUTOCOMPLETE_RESULTS,
      load: false,
      misspellings: false,
      highlight: { tag: "<mark>", encoder: "html" }
    }

    pages_results = Page.autocomplete(params[:query], common_options)
    term_results = TermNode.search(params[:query], common_options.merge({
      fields: ['name']
    }))
    pages_simple = simple_results(pages_results, "scientific_name", params[:query], "pages")
    terms_simple = simple_results(term_results, "name", params[:query], "term_nodes")
    render json: pages_simple.concat(terms_simple)[0, MAX_AUTOCOMPLETE_RESULTS]
  end

private
  def simple_results(full_results, default_name_field, query, controller)
    result_hash = {}
    full_results.each do |r|
      field = r['highlight']&.first&.first&.split('.').first
      name = r.send(field) || r.send(default_name_field)
      if name.is_a?(Array)
        first_hit = name.grep(/#{query}/i)&.first
        name = first_hit || name.first
      end
      result_hash[name] =
        if result_hash.key?(name)
          new_string = params[:no_multiple_text] ? name : "#{name} (multiple hits)"
          { name: new_string, title: new_string, id: r.id, url: search_path(q: name, utf8: true) }
        else
          { name: name, title: name, id: r.id, url: url_for(controller: controller, action: "show", id: r.id) }
        end
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
    @images = searcher.images
    @videos = searcher.videos
    @sounds = searcher.sounds
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
