class SearchController < ApplicationController
  # TODO: Mammoth method, break up.
  def search
    # Doctoring for the view to find matches:
    @q = params[:q]
    @q.chop! if params[:q] =~ /\*$/
    @q = @q[1..-1] if params[:q] =~ /^\*/

    # TODO: we'll want some whitelist filtering here later:
    params[:q] = "#{@q}*" unless params[:q] =~ /\*$/

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
    @pages = search_class(Page, include: [:medium, native_node: :rank,
      vernaculars: :language ], page_richness: true)
    @collections = search_class(Collection)
    @media = search_class(Medium)
    @users = search_class(User)

    if @types[:object_terms]
      # NOTE we use @q here because it has no wildcard.
      @object_terms = TraitBank.search_object_terms(@q)
    end

    if @types[:predicates]
      # NOTE we use @q here because it has no wildcard.
      @predicates = TraitBank.search_predicate_terms(@q)
    end

    respond_to do |fmt|
      fmt.html do
        @page_title = t(:page_title_search, query: @q)
        @empty = true
        [ @pages, @collections, @media, @users ].each do |set|
          @empty = false if set && ! set.results.empty?
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

  def names
    respond_to do |fmt|
      fmt.json do
        q = Page.search do
          fulltext "#{params[:name]}*" do
            Page.stored_fields.each do |field|
              highlight field
            end
          end
          order_by(:page_richness, :desc)
          paginate page: 1, per_page: 10
        end
        matches = {}
        results = []
        q.hits.each do |hit|
          Page.stored_fields.each do |field|
            hit.highlights(field).compact.each do |highlight|
              word = highlight.format { |word| word }
              word = word.downcase if field == :name ||
                field == :preferred_vernaculars ||
                field == :vernaculars
              results << { value: word, tokens: word.split } unless
                matches.has_key?(word.downcase)
              # NOTE: :name is a tricky little field. ...it COULD be a
              # scientific_name, in which case we don't want to downcase it! So
              # we store the DOWNCASED name as the key. ...Scientific names are
              # checked first (because they appear first in Page.stored_fields),
              # so they will take precendence over the name.
              matches[word.downcase] = true
            end
          end
        end
        results = results.sort_by { |r| r[:value] }
        render json: JSON.pretty_generate(results)
      end
    end
  end

  private

  # TODO: Whoa, you can do them all at the same time! I'm not sure we *want* to,
  # though, so I'm holding this comment here:
  # ss = Sunspot.search [Page, Medium] { fulltext "raccoon*" } ; ss.results

  def search_class(klass, options = {})
    # NOTE: @q DOES NOT WORK in search blocks, and you can't call external
    # methods.
    page_richness = options.delete(:page_richness)
    if @types[klass.name.tableize.to_sym]
      klass.send(:search, options) do
        if params[:q] =~ /\*$/
          any do
            fulltext params[:q]
            fulltext params[:q].sub(/\*$/, "")
          end
        else
          fulltext params[:q]
        end
        if page_richness
          order_by(:page_richness, :desc)
        end
        paginate page: params[:page] || 1, per_page: params[:per_page] || 30
      end
    end
  end
end
