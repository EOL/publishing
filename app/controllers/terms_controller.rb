class TermsController < ApplicationController
  before_filter :require_admin, only: [:fetch_units, :update]

  SCHEMA_URI_FORMAT = "http://eol.org/schema/terms/%s"

  def index
    @uri = params[:uri]
    glossary_for_letter(params[:letter])
  end

  def schema_redirect
    term = TraitBank.term_as_hash(SCHEMA_URI_FORMAT % params[:uri_part])
    raise ActionController.RoutingError.new("Not Found") if !term
    first_letter = TraitBank::Terms.letter_for_term(term)
    redirect_to terms_path(letter: first_letter, uri: term[:uri]), status: 302 
  end

  def edit
    @term = TraitBank.term_as_hash(params[:uri])
  end

  def fetch_relationships
    raise "unauthorized" unless is_admin? # TODO: generalize
    @log = []
    count = TraitBank::Terms::Relationships.fetch_parent_child_relationships(@log)
    @log << "Loaded #{count} parent/child relationships."
  end

  def fetch_synonyms
    raise "unauthorized" unless is_admin? # TODO: generalize
    @log = []
    count = TraitBank::Terms::Relationships.fetch_synonyms(@log)
    @log << "Loaded #{count} synonym relationships."
    render :fetch_relationships # same log-only layout.
  end

  def fetch_units
    @log = []
    count = TraitBank::Terms::Relationships.fetch_units(@log)
    @log << "Loaded #{count} predicate/unit relationships."
    render :fetch_relationships # same log-only layout.
  end

  def update
    term = params[:term].merge(uri: params[:uri])
    # TODO: sections ...  I can't properly test that right now.
    TraitBank.update_term(term) # NOTE: *NOT* hash!
    redirect_to(term_path(term[:uri]))
  end

  def predicate_glossary
    glossary(params[:action], count_method: :predicate_glossary_count)
  end

  # We ultimately don't want to just pass a "URI" to the term search; we need to
  # separate object terms and predicates. We handle that here, since there are
  # two places where it matters.
  def add_uri_to_options(options)
    if @object
      options[:predicate] = @and_predicate && @and_predicate[:uri]
      options[:object_term] = @and_object ?
        [@term[:uri], @and_object[:uri]] :
        @term[:uri]
    else
      options[:predicate] = @and_predicate ?
        [@term[:uri], @and_predicate[:uri]] :
        @term[:uri]
      options[:object_term] = @and_object && @and_object[:uri]
    end
  end

  def object_terms_for_pred
    pred = params[:pred_uri]
    q = params[:query]
    res = TraitBank::Terms.obj_terms_for_pred(pred, q) # NOTE: this is already cached by the class. ...is that wise?
    render :json => res
  end

  def object_term_glossary
    glossary(params[:action], count_method: :object_term_glossary_count)
  end

  def units_glossary
    glossary(params[:action], count_method: :units_glossary_count)
  end

  def pred_autocomplete
    q = params[:query]
    res = Rails.cache.fetch("pred_autocomplete/#{q}") { TraitBank::Terms.predicate_glossary(nil, nil, qterm: q) }
    render :json => res
  end

private
  def glossary(which, options = nil)
    @count = TraitBank::Terms.send(options[:count_method] || :count)

    respond_to do |fmt|
      fmt.html do
        @glossary = glossary_helper(which, @count, true)
      end
      fmt.json do
        render json: glossary_helper(which, @count, false)
      end
    end
  end

  def glossary_helper(which, count, paginate)
    @per_page = params[:per_page] || Rails.configuration.data_glossary_page_size
    @page = params[:page] || 1
    query = params[:query]
    @per_page = 10 if !paginate
    if params[:reindex] && is_admin?
      TraitBank::Admin.clear_caches
      expire_trait_fragments
    end
    result = TraitBank::Terms.send(which, @page, @per_page, qterm: query, for_select: !paginate)
    Rails.logger.warn "GLOSSARY RESULTS: (for select: #{!paginate}) #{result.map { |r| r[:name] }.join(', ')}"
    paginate ? Kaminari.paginate_array(result, total_count: count).page(@page).per(@per_page) : result[0..@per_page+1]
  end

  def glossary_for_letter(letter)
    @letter = letter
    @letters = TraitBank::Terms.letters_for_glossary
    @glossary = @letter ? 
      TraitBank::Terms.glossary_for_letter(@letter) :
      []
  end

  def expire_trait_fragments
    (0..100).each do |index|
      expire_fragment("term/glossary/#{index}")
    end
  end
end
