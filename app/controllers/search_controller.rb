class SearchController < ApplicationController
  # TODO: Mammoth method, break up.
  def search
    # Doctoring for the view to find matches:
    @q = params[:q]
    @q.chop! if params[:q] =~ /\*$/
    @q = @q[1..-1] if params[:q] =~ /^\*/

    # TODO: we'll want some whitelist filtering here later:
    # params[:q] = "#{@q}*" unless params[:q] =~ /\*$/ or params[:q] =~ /^[-+]/ or params[:q] =~ /\s/
    params[:q] = I18n.transliterate(params[:q]).downcase

    # First step (and, yes, this will be slow—we will optimize later), look for
    # search suggestions that match the query:
    words = params[:q].split # TODO: we might want to remove words with ^-
    suggestions = SearchSuggestion.search(params[:q],
      fields: [{ match: :exact }])

    # If we only found one thing and they only asked for one thing:
    if suggestions.size == 1 && params[:q] !~ /\s/
      # TODO: move this to a helper? It can't go on the model...
      suggestion = suggestions.first
      suggestion = suggestion.synonym_of if suggestion.synonym_of
      where = if suggestion.page_id
          suggestion.page
        elsif suggestion.object_term
          term_path(uri: suggestion.object_term, object: true)
        elsif suggestion.path
          suggestion.path
        elsif suggestion.wkt_string
          flash[:notice] = "Unimplemented, sorry."
          "/"
        end
      return redirect_to(where)
    end


    @clade = if params[:clade]
      puts "*" * 100
      puts "** Filtering by clade #{params[:clade]}"
      # It doesn't make sense to filter some things by clade:
      params[:only] = if params[:only]
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
    [ :pages, :collections, :media, :users, :predicates, :object_terms ].
      each do |sym|
        @types[sym] = default
      end

    if params.has_key?(:only)
      Array(params[:only]).each { |type| @types[type.to_sym] = true }
    elsif params.has_key?(:except)
      Array(params[:except]).each { |type| @types[type.to_sym] = false }
    end

    # NOTE: no search is performed unless the @types hash indicates a search for
    # that class is required:

    @pages = if @types[:pages]
      basic_search(Page, boost_by: { page_richness: { factor: 0.01 } },
        fields: ["preferred_vernacular_strings^200", "scientific_name^400",
          "vernacular_strings", "synonyms", "providers", "resource_pks"],
          where: @clade ? { ancestry_ids: @clade.id } : nil)
    else
      nil
    end

    @collections = if @types[:collections]
      basic_search(Collection, fields: ["name^5", "description"])
    else
      nil
    end

    # YOU WERE HERE. ...for some reason, this isn't working IF there is a clade
    # specified; it's returning no results in that case. Can you put all of
    # these in one index? We don't need them broken up...

    @media = if @types[:media]
      basic_search(Searchkick,
        fields: ["name^5", "resource_pk^10", "owner", "description^2"],
        where: @clade ? { ancestry_ids: @clade.id } : nil,
        index_name: [Article, Medium, Link])
    else
      nil
    end

    @users = if @types[:users]
      basic_search(User, fields: ["username^6", "name^4", "tag_line", "bio^2"])
    else
      nil
    end

    Searchkick.multi_search([@pages, @collections, @media, @users].compact)

    if @types[:predicates]
      @predicates_count = TraitBank.count_predicate_terms(@q)
      # NOTE we use @q here because it has no wildcard.
      @predicates = Kaminari.paginate_array(
        TraitBank.search_predicate_terms(@q, params[:page], params[:per_page]),
        total_count: @predicates_count
      ).page(params[:page]).per(params[:per_page] || 50)
    end

    if @types[:object_terms]
      @object_terms_count = TraitBank.count_object_terms(@q)
      # NOTE we use @q here because it has no wildcard.
      @object_terms = Kaminari.paginate_array(
        TraitBank.search_object_terms(@q, params[:page], params[:per_page]),
        total_count: @object_terms_count
      ).page(params[:page]).per(params[:per_page] || 50)
    end

    respond_to do |fmt|
      fmt.html do
        @page_title = t(:page_title_search, query: @q)
        @empty = true
        [ @pages, @collections, @media, @users ].each do |set|
          @empty = false if set && ! set.empty?
        end
        # Object terms is unusual:
        @empty = false if @object_terms && ! @object_terms.empty?
        @empty = false if @predicates && ! @predicates.empty?
      end

      fmt.js { }

      # TODO: JSON results for other types! TODO: move: this is view logic...
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

private

  def basic_search(klass, options = {})
    klass.search(params[:q], options.reverse_merge(highlight: { tag: "**" },
      execute: false, page: params[:page], per_page: 50))
  end
end
