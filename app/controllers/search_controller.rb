class SearchController < ApplicationController
  # TODO: Mammoth method, break up.
  def search
    # Doctoring for the view to find matches:
    @q = params[:q]
    @q.chop! if params[:q] =~ /\*$/
    @q = @q[1..-1] if params[:q] =~ /^\*/

    # TODO: we'll want some whitelist filtering here later:
    params[:q] = "#{@q}*" unless params[:q] =~ /\*$/ or params[:q] =~ /^[-+]/ or params[:q] =~ /\s/
    params[:q] = I18n.transliterate(params[:q]).downcase

    @clade = if params[:clade]
      puts "*" * 100
      puts "** Filtering by clade #{params[:clade]}"
      # It doesn't make sense to filter some things by clade:
      params[:only] = if params[:only]
        [:pages, :media] - params[:only]
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
    # TEST TEST TEST TEST TEST TEST TEST TEST TEST TEST TEST TEST TEST TEST
    @pages = Page.search(params[:q]).page(params[:page]).per(50)
    @collections = nil
    @media = nil
    @users = nil

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

  def names
    respond_to do |fmt|
      fmt.json do
        # TODO: add weight to exact matches. Not sure how, yet. :S
        q = Page.search do
          fulltext "#{params[:name].downcase}*" do
            Page.stored_fields.each do |field|
              highlight field
            end
          end
          order_by(:page_richness, :desc)
          # NOTE: the per_page here is ALSO restricted in main.js! Be careful.
          paginate page: 1, per_page: 20
        end
        matches = {}
        pages = {}
        results = []
        q.hits.each do |hit|
          Page.stored_fields.each do |field|
            hit.highlights(field).compact.each do |highlight|
              word = highlight.format { |word| word }
              word = word.downcase if field == :name ||
                field == :preferred_vernaculars ||
                field == :vernaculars
              unless matches.has_key?(word.downcase) || pages.has_key?(hit.primary_key)
                results << { value: word, tokens: word.split, id: hit.primary_key }
                # NOTE: :name is a tricky little field. ...it COULD be a
                # scientific_name, in which case we don't want to downcase it!
                # So we store the DOWNCASED name as the key. ...Scientific names
                # are checked first (because they appear first in
                # Page.stored_fields), so they will take precendence over the
                # name.
                matches[word.downcase] = true
                pages[hit.primary_key] = true
              end
            end
          end
        end
        render json: JSON.pretty_generate(results)
      end
    end
  end
end
