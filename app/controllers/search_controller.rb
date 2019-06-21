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

  # TODO: Mammoth method, break up.
  def do_search
    @search_text = params[:q]

    # Doctoring for the view to find matches:
    @q = @search_text
    @q.chop! if params[:q] =~ /\*$/
    @q = @q[1..-1] if params[:q] =~ /^\*/

    # TODO: we'll want some whitelist filtering here later:
    # params[:q] = "#{@q}*" unless params[:q] =~ /\*$/ or params[:q] =~ /^[-+]/ or params[:q] =~ /\s/
    # TODO: transliterate is SLOW! We only do it when we detect we (might) need to...
    params[:q] = I18n.transliterate(params[:q]) unless params[:q].ascii_only?
    params[:q].downcase!

    # TODO: This search suggestions block is large; extract.

    # First step (and, yes, this will be slow—we will optimize later), look for
    # search suggestions that match the query:
    words = params[:q].split # TODO: we might want to remove words with ^-
    # TODO: we might also want to remove stopwords e.g.: https://github.com/brenes/stopwords-filter
    suggestions = []
    # YUCK! This is the best way to do this in Searchkick at the moment, though.
    # :S
    words.each do |word|
      word_search = SearchSuggestion.search(word, fields: [{ match: :exact }])
      suggestions += word_search.results if word_search.respond_to?(:results)
    end

    # If we only found one thing and they only asked for one thing:
    if suggestions.size == 1 && params[:q] !~ /\s/
      Rails.logger.warn("One suggestion.")
      # TODO: move this to a helper? It can't go on the model...
      suggestion = suggestions.first
      suggestion = suggestion.synonym_of if suggestion.synonym_of
      where =
        case suggestion.type
        when :page
          suggestion.page
        when :object_term
          term_records_path(uri: suggestion.object_term, object: true)
        when :path
          suggestion.path
        when :wkt_string
          flash[:notice] = "Unimplemented, sorry."
          "/"
        end
      return redirect_to(where)
    elsif suggestions.size >= 2 && params[:q] =~ /\s/
      Rails.logger.warn("Multiple suggestions.")
      groups = suggestions.group_by(&:type)
      # Easier to handle:
      groups[:page] ||= []
      groups[:object_term] ||= []
      groups[:path] ||= []
      groups[:wkt_string] ||= []
      if groups[:page].size > 1
        Rails.logger.warn("Multiple PAGE suggestions.")
        # We can't use suggestions if there's more than one species. Sorry.
        flash[:notice] = t("search.flash.more_than_one_species",
          species: groups[:page].map(&:match).to_sentence)
      else
        Rails.logger.warn("0 or 1 Page suggestions.")
        clade = groups[:page].try(:first).try(:page_id)
        Rails.logger.warn("Page suggestion: #{clade}") if clade
        if groups[:object_term].size > 2
          Rails.logger.warn("Over two TERM suggestions.")
          flash[:notice] = t("search.flash.more_than_two_terms",
            terms: groups[:object_term].map(&:match).to_sentence)
        elsif groups[:path].size > 0
          Rails.logger.warn("...had PATH suggestions.")
          flash[:notice] = t("search.flash.cannot_combine_paths",
            path: groups[:path].map(&:match).to_sentence)
        else # NOTE: this assumes we only have OBJECT term suggestions, not predicates.
          Rails.logger.warn("Usable suggestions...")
          (first, second) = groups[:object_term] # Arbitrary which is first...
          Rails.logger.warn("First term: #{first.object_term}")
          Rails.logger.warn("Second term: #{second.object_term}") if second
          return redirect_to(term_records_path(uri: first.object_term, object: true,
            and_object: second.try(:object_term), clade: clade))
        end
      end
    end

    @clade =
      if params[:clade]
        puts "*" * 100
        puts "** Filtering by clade #{params[:clade]}"
        # It doesn't make sense to filter some things by clade:
        params[:only] =
          if params[:only]
            Array(params[:only]) - [:collections, :users, :predicates, :object_terms]
          else
            [:pages, :media]
          end
        puts "Only param should now be: #{params[:only]}"
        Page.find(params[:clade])
      else
        nil
      end

    default = params.has_key?(:only)? false : true
    @types = {}
    #[ :pages, :collections, :articles, :images, :videos, :videos, :sounds, :links, :users, :predicates, :object_terms ].
    [ :pages, :collections, :articles, :images, :videos, :videos, :sounds, :links, :users, :terms ].
      each do |sym|
        @types[sym] = default
      end

    @types[params[:only].to_sym] = true if params.has_key?(:only)

    # if params.has_key?(:only)
    #   Array(params[:only]).each { |type| @types[type.to_sym] = true }
    # elsif params.has_key?(:except)
    #   Array(params[:except]).each { |type| @types[type.to_sym] = false }
    # end

    # NOTE: no search is performed unless the @types hash indicates a search for
    # that class is required:

    @pages =
      if @types[:pages]
        fields = %w[preferred_vernacular_strings^20 vernacular_strings^20 preferred_scientific_names^10 scientific_name^10 synonyms^10 providers resource_pks]
        match = words.size == 1 ? :text_start : :phrase
        basic_search(Page, boost_by: [:page_richness, :specificity, :depth], match: match, fields: fields,
                           where: @clade ? { ancestry_ids: @clade.id } : nil,
                           includes: [:preferred_vernaculars, :medium, { native_node: { node_ancestors: :ancestor } }])
      else
        nil
      end


    @collections =
      if @types[:collections]
        basic_search(Collection, fields: ["name^5", "description"])
      else
        nil
      end

    @articles =
      if @types[:articles]
        basic_search(Searchkick,
          fields: ["name^5", "resource_pk^10", "owner", "description^2"],
          where: @clade ? { ancestry_ids: @clade.id } : nil,
          index_name: [Article])
      else
        nil
      end

    @images =
      if @types[:images]
        media_search("image")
      else
        nil
      end

    @videos =
      if @types[:videos]
        media_search("video")
      else
        nil
      end

    @sounds =
      if @types[:sounds]
        media_search("sound")
      else
        nil
      end

    @terms =
      if @types[:terms]
        basic_search(TermNode, fields: ["name"])
      else
        nil
      end

    # @links = if @types[:links]
    #   basic_search(Searchkick,
    #     fields: ["name^5", "resource_pk^10", "owner", "description^2"],
    #     where: @clade ? { ancestry_ids: @clade.id } : nil,
    #     index_name: [Link])
    # else
    #   nil
    # end

    @users =
      if @types[:users]
        basic_search(User, fields: ["username^6", "name^4", "tag_line", "bio^2"])
      else
        nil
      end

    Searchkick.multi_search([@pages, @articles, @images, @videos, @sounds, @collections, @users, @terms].compact)

    @pages = PageSearchDecorator.decorate_collection(@pages) if @pages
    remove_zombie_pages if @pages
    @articles = ArticleSearchDecorator.decorate_collection(@articles) if @articles
    @images = ImageSearchDecorator.decorate_collection(@images) if @images
    @videos = VideoSearchDecorator.decorate_collection(@videos) if @videos
    @sounds = SoundSearchDecorator.decorate_collection(@sounds) if @sounds
    @collections = CollectionSearchDecorator.decorate_collection(@collections) if @collections
    @users = UserSearchDecorator.decorate_collection(@users) if @users
    @terms = TermSearchDecorator.decorate_collection(@terms) if @terms

    # if @types[:predicates]
    #   @predicates_count = TraitBank.count_predicate_terms(@q)
    #   # NOTE we use @q here because it has no wildcard.
    #   @predicates = Kaminari.paginate_array(
    #     TraitBank.search_predicate_terms(@q, params[:page], params[:per_page]),
    #     total_count: @predicates_count
    #   ).page(params[:page]).per(params[:per_page] || 50)
    # end
    #
    # if @types[:object_terms]
    #   @object_terms_count = TraitBank.count_object_terms(@q)
    #   # NOTE we use @q here because it has no wildcard.
    #   @object_terms = Kaminari.paginate_array(
    #     TraitBank.search_object_terms(@q, params[:page], params[:per_page]),
    #     total_count: @object_terms_count
    #   ).page(params[:page]).per(params[:per_page] || 50)
    # end

    respond_to do |fmt|
      fmt.html do
        @page_title = t(:page_title_search, query: @q)
      end

      fmt.js { }

      # TODO: JSON results for other types! TODO: move; this is view logic...
      fmt.json do
        render json: JSON.pretty_generate(@pages.results.as_json(
          except: :native_node_id,
          methods: :scientific_name,
          include: {
            preferred_vernaculars: { only: [:string],
              include: { language: { only: :code } } },
            # NOTE I'm excluding a lot more for search than you would want for
            # the basic page json:
            top_media: { only: [ :id, :guid, :owner, :name ],
              methods: [:small_icon_url, :medium_icon_url],
              include: { provider: { only: [:id, :name] },
                license: { only: [:id, :name, :icon_url] } } }
          }
        ))
      end
    end
  end

  def basic_search(klass, options = {})
    klass.search(params[:q], options.reverse_merge(highlight: { tag: "<mark>", encoder: "html" },
      match: :word_start, execute: false, page: params[:page], per_page: 50))
  end

  def media_search(subtype_str)
    where = { :subclass => subtype_str}
    where.merge!({ :ancestry_ids => @clade.id }) if @clade

    basic_search(Searchkick,
      fields: ["name^5", "resource_pk^10", "owner", "description^2"],
      where: where,
      index_name: [Medium])
  end

  # So-called "self-healing" code for pages that have no native node and were probably deleted:
  def remove_zombie_pages
    bad_page_ids = []
    @pages.each do |page|
      id = if page.respond_to?(:page_id) # Search decotrator
        page.page_id
      else
        page.id
      end
      bad_page_ids << id if page.native_node.nil?
    end
    return if bad_page_ids.empty?
    Page.where(id: bad_page_ids).includes(:nodes).each do |page|
      if page.nodes.empty?
        Page.search_index.remove(page)
        page.delete
      end
    end
    begin # This is really reaching into the innards of the class, but I can't find an alternative:
      @pages.response["hits"]["hits"].delete_if { |hit| bad_page_ids.include?(hit["_id"]) }
    rescue
      # Nothing we can do, it will render a "NO NAME!" result, which is better than the alternative.
    end
  end
end
