class MultiClassSearch
  attr_accessor :query, :notice, :pages, :collections, :articles, :images, :videos, :sounds, :terms, :users

  def initialize(query, options = {})
    @search_text = query.dup
    @only = options.key?(:only) ? Array(options[:only]) : []
    @page = options[:page] # Allows searches within a specific page.
    set_clade(options[:clade])
    @q = @search_text
    @q.chop! if query =~ /\*$/
    @q = @q[1..-1] if query =~ /^\*/
    clean_query(query)
    build_words_and_suggestions
    set_types
  end

  def clean_query(query)
    @query = query
    # TODO: we'll want some whitelist filtering here later:
    # @query = "#{@q}*" unless @query =~ /\*$/ or @query =~ /^[-+]/ or @query =~ /\s/
    # TODO: transliterate is SLOW! We only do it when we detect we (might) need to...
    @query = I18n.transliterate(query) unless query.ascii_only?
    @query.downcase!
  end

  def set_clade(clade)
    @clade =
      if clade
        # It doesn't make sense to filter some things by clade:
        @only =
          if @only
            @only - [:collections, :users, :predicates, :object_terms]
          else
            [:pages, :media]
          end
        Page.find(clade)
      else
        nil
      end
  end

  def build_words_and_suggestions
    @words = @query.split # TODO: we might want to remove words with ^-
    # TODO: we might also want to remove stopwords e.g.: https://github.com/brenes/stopwords-filter
    @suggestions = []
    # YUCK! This is the best way to do this in Searchkick at the moment, though.
    # :S
    @words.each do |word|
      word_search = SearchSuggestion.search(word, fields: [{ match: :exact }])
      @suggestions += word_search.results if word_search.respond_to?(:results)
    end
  end

  # If we only found one thing and they only asked for one thing:
  def suggested_path?
    if one_suggestion?
      suggested_path
    elsif many_suggestions?
      multiple_suggestions
    end
  end

  def group_suggestions
    groups = @suggestions.group_by(&:type)
    groups[:page] ||= []
    groups[:object_term] ||= []
    groups[:path] ||= []
    groups[:wkt_string] ||= []
    groups
  end

  def one_suggestion?
    @suggestions.size == 1 && @query !~ /\s/
  end

  def many_suggestions?
    @suggestions.size >= 2 && @query =~ /\s/
  end

  def suggested_path
    suggestion = @suggestions.first
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
        @notice = "Unimplemented, sorry."
        "/"
      end
    return redirect_to(where)
  end

  def multiple_suggestions
    Rails.logger.warn("Multiple suggestions.")
    groups = group_suggestions
    if groups[:page].size > 1
      Rails.logger.warn("Multiple PAGE suggestions.")
      @notice = I18n.t("search.flash.more_than_one_species", species: groups[:page].map(&:match).to_sentence)
    else
      Rails.logger.warn("0 or 1 Page suggestions.")
      clade = groups[:page].try(:first).try(:page_id)
      Rails.logger.warn("Page suggestion: #{clade}") if clade
      if groups[:object_term].size > 2
        Rails.logger.warn("Over two TERM suggestions.")
        @notice = I18n.t("search.flash.more_than_two_terms", terms: groups[:object_term].map(&:match).to_sentence)
        nil
      elsif groups[:path].size > 0
        Rails.logger.warn("...had PATH suggestions.")
        @notice = I18n.t("search.flash.cannot_combine_paths", path: groups[:path].map(&:match).to_sentence)
        nil
      else # NOTE: this assumes we only have OBJECT term suggestions, not predicates.
        (first, second) = groups[:object_term] # Arbitrary which is first...
        Rails.logger.warn("Usable suggestions. First term: #{first.object_term}")
        Rails.logger.warn("Second term: #{second.object_term}") if second
        term_records_path(uri: first.object_term, object: true, and_object: second.try(:object_term), clade: clade)
      end
    end
  end

  def term_records_path(options)
    Rails.application.routes.url_helpers.term_records_path(options)
  end

  def set_types
    only_set = Set.new(@only.collect { |o| o.to_sym })

    @types = {}
    [ :pages, :collections, :articles, :images, :videos, :videos, :sounds, :links, :users, :terms ].each do |sym|
      @types[sym] = only_set.empty? || only_set.include?(sym)
    end
  end

  def search
    @pages = prepare_pages_query
    @collections = prepare_collections_query
    @articles = prepare_articles_query
    @images = prepare_images_query
    @videos = prepare_videos_query
    @sounds = prepare_sounds_query
    @terms = prepare_terms_query
    @users = prepare_users_query
    Searchkick.multi_search([@pages, @articles, @images, @videos, @sounds, @collections, @users, @terms].compact)
    decorate_results
  end

  def prepare_pages_query
    if @types[:pages]
      #fields = %w[autocomplete_names^20 synonyms]
      fields = %w[preferred_vernacular_strings^20 vernacular_strings^20 preferred_scientific_names^10 scientific_name^10 synonyms^10 providers resource_pks] 
      match = @words.size == 1 ? :text_start : :phrase
      basic_search(
        Page,
        match: match,
        fields: fields,
        where: @clade ? { ancestry_ids: @clade.id } : nil,
        includes: [:preferred_vernaculars, :medium, { native_node: { node_ancestors: :ancestor } }]
      )
    else
      nil
    end
  end

  def prepare_collections_query
    if @types[:collections]
      basic_search(Collection, fields: ["name^5", "description"])
    else
      nil
    end
  end

  def prepare_articles_query
    if @types[:articles]
      basic_search(Searchkick,
        fields: ["name^5", "resource_pk^10", "owner", "description^2"],
        where: @clade ? { ancestry_ids: @clade.id } : nil,
        index_name: [Article])
    else
      nil
    end
  end

  def prepare_images_query
    if @types[:images]
      media_search("image")
    else
      nil
    end
  end

  def prepare_videos_query
    if @types[:videos]
      media_search("video")
    else
      nil
    end
  end

  def prepare_sounds_query
    if @types[:sounds]
      media_search("sound")
    else
      nil
    end
  end

  def prepare_terms_query
    if @types[:terms]
      basic_search(TermNode, fields: ["name"])
    else
      nil
    end
  end

  def prepare_users_query
    if @types[:users]
      basic_search(User, fields: ["username^6", "name^4", "tag_line", "bio^2"])
    else
      nil
    end
  end

  def decorate_results
    @pages = PageSearchDecorator.decorate_collection(@pages) if @pages
    remove_zombie_pages if @pages
    @articles = ArticleSearchDecorator.decorate_collection(@articles) if @articles
    @images = ImageSearchDecorator.decorate_collection(@images) if @images
    @videos = VideoSearchDecorator.decorate_collection(@videos) if @videos
    @sounds = SoundSearchDecorator.decorate_collection(@sounds) if @sounds
    @collections = CollectionSearchDecorator.decorate_collection(@collections) if @collections
    @users = UserSearchDecorator.decorate_collection(@users) if @users
    @terms = TermSearchDecorator.decorate_collection(@terms) if @terms
  end

  def errors
    errors = []

    [@pages, @articles, @images, @videos, @sounds, @collections, @users, @terms].each do |type|
      if !type.nil? && type.error
        errors << type.error
      end
    end

    errors
  end 

  def basic_search(klass, options = {})
    klass.search(@query, options.reverse_merge(highlight: { tag: "<mark>", encoder: "html" },
      match: :word_start, execute: false, page: @page, per_page: 50))
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
      id =  if page.respond_to?(:page_id) # Search decotrator
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
