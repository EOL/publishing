class TermsController < ApplicationController
  include DataAssociations
  helper :data

  before_filter :require_admin, only: [:fetch_units, :update]

  before_action :no_main_container, only: [:search, :search_results, :search_form, :show]
  before_action :build_query, only: [:search_results, :search_form]

  def index
    glossary("full_glossary", count_method: :count)
  end

  def search
    @query = TermQuery.new(:result_type => :taxa)
    @query.filters.build(:op => :is_any)
  end

  def search_results
    respond_to do |fmt|
      fmt.html do
        if @query.valid?
          Rails.logger.warn @query.to_s
          search_common
        else
          render "search"
        end
      end

      fmt.csv do
        if !current_user
          redirect_to new_user_session_path
        else
          if @query.valid?
            url = term_search_results_url(:term_query => tq_params)
            data = TraitBank::DataDownload.term_search(@query, current_user.id, url)

            if data.is_a?(UserDownload)
              flash[:notice] = t("user_download.created", url: user_path(current_user))
              redirect_no_format
            else
              send_data data
            end
          else
            redirect_no_format
          end
        end
      end
    end
  end

  def search_form
    render :layout => false
  end

  def show
    filter_options = if params[:obj_uri]
      {
        :op => :is_obj,
        :pred_uri => params[:uri],
        :obj_uri => params[:obj_uri]
      }
    else
      {
        :op => :is_any,
        :pred_uri => params[:uri]
      }
    end

    @query = TermQuery.new({
      :filters => [TermQueryFilter.new(filter_options)],
      :result_type => :record
    })
    search_common
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
  def tq_params
    params.require(:term_query).permit([
      :clade_id,
      :result_type,
      :filters_attributes => [
        :pred_uri,
        :obj_uri,
        :op,
        :num_val1,
        :num_val2,
        :units_uri
      ]
    ])
  end

  def build_query
    @query = TermQuery.new(tq_params)
    @query.filters.delete @query.filters[params[:remove_filter].to_i] if params[:remove_filter]
    @query.filters.build(:op => :is_any) if params[:add_filter]
    blank_predicate_filters_must_search_any
  end

  # TODO: Does this logic belong in TermQuery?
  def blank_predicate_filters_must_search_any
    @query.filters.each { |f| f.op = :is_any if f.pred_uri.blank? }
  end

  def paginate_term_search_data(data, query)
    options = {
      :count => true,
    }
    Rails.logger.warn "&&TS Running count:"
    @count = TraitBank.term_search(query, options)
    @grouped_data = Kaminari.paginate_array(data, total_count: @count).page(@page).per(@per_page)

    if query.taxa?
      @result_pages = @grouped_data.map do |datum|
        @pages[datum[:page_id]]
      end.compact

      @result_pages = PageSearchDecorator.decorate_collection(@result_pages)
    end
  end

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

  def expire_trait_fragments
    (0..100).each do |index|
      expire_fragment("term/glossary/#{index}")
    end
  end

  def permitted_filter_params(filter_params)
    filter_params.permit(
      :pred_uri,
      :uri,
      :value,
      :from_value,
      :to_value,
      :units_uri
    )
  end

  def search_common
    @page = params[:page] || 1
    @per_page = 50
    Rails.logger.warn "&&TS Running search:"
    res = TraitBank.term_search(@query, {
      :page => @page,
      :per => @per_page,
    })
    data = res[:data]
    @raw_query = res[:raw_query]
    @raw_res = res[:raw_res].to_json
    ids = data.map { |t| t[:page_id] }.uniq
    # HERE IS THE IMPORTANT DB QUERY TO LOAD PAGES:
    pages = Page.where(:id => ids).for_search_results
    @pages = {}

    ids.each do |id|
      page = pages.find { |p| p.id == id }
      @pages[id] = page if page
    end

    # TODO: code review here. I think we're creating a lot of cruft we don't use.
    paginate_term_search_data(data, @query)
    @is_terms_search = true
    @resources = TraitBank.resources(data)
    build_associations(data)
    render "search"
  end

  def redirect_no_format
    loc = params
    loc.delete(:format)
    redirect_to term_search_results_path(params)
  end
end
