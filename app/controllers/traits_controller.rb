class TraitsController < ApplicationController
  include DataAssociations

  helper :data

  before_action :no_main_container, only: [:search, :search_results, :search_form, :show]
  before_action :build_query, only: [:search_results, :search_form]
  before_action :set_title, only: [:search, :search_results]

  PER_PAGE = 50
  GBIF_LINK_LIMIT = PER_PAGE
  GBIF_DOWNLOAD_LIMIT = 100_000
  GBIF_BASE_URL = "https://www.gbif.org/occurrence/map"
  VIEW_TYPES = Set.new(%w(list gallery))

  DataViz = Struct.new(:type, :data)

  def search
    @query = TermQuery.new(:result_type => :taxa)
    @query.filters.build
  end

  def search_results
    set_view_type
    @query.remove_really_blank_filters

    respond_to do |fmt|
      fmt.html do
        if @query.valid?
          Rails.logger.warn @query.to_s
          search_common
        else
          @query.add_filter_if_none
          render "search"
        end
      end

      fmt.csv do
        if !current_user
          redirect_to new_user_session_path
        else
          if @query.valid?
            url = term_search_results_url(:term_query => tq_params)
            if UserDownload.user_has_pending_for_query?(current_user, @query)
              flash[:notice] = t("user_download.have_pending", url: user_path(current_user))
              redirect_no_format
            else
              data = TraitBank::DataDownload.term_search(@query, current_user.id, url)

              if data.is_a?(UserDownload)
                flash[:notice] = t("user_download.created", url: user_path(current_user))
                redirect_no_format
              else
                send_data data
              end
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
        :pred_uri => params[:uri],
        :obj_uri => params[:obj_uri]
      }
    else
      {
        :pred_uri => params[:uri]
      }
    end

    @query = TermQuery.new({
      :filters => [TermQueryFilter.new(filter_options)],
      :result_type => :record
    })
    search_common
  end

  private
  def tq_params
    params.require(:term_query).permit(TermQuery.expected_params)
  end

  def build_query
    @query = TermQuery.new(tq_params)
    @query.filters[params[:show_extra_fields].to_i].show_extra_fields = true if params[:show_extra_fields]
    @query.filters[params[:hide_extra_fields].to_i].clear_extra_fields if params[:hide_extra_fields]
    @query.filters.delete @query.filters[params[:remove_filter].to_i] if params[:remove_filter]
    @query.filters.build(:op => :is_any) if params[:add_filter]
    blank_predicate_filters_must_search_any
  end

  # TODO: Does this logic belong in TermQuery?
  def blank_predicate_filters_must_search_any
    @query.filters.each { |f| f.op = :is_any if f.pred_uri.blank? }
  end

  def paginate_term_search_data(data, query)
    Rails.logger.warn "&&TS Running count:"
    # @count = 1_000_000
    @counts = TraitBank.term_search(query, { count: true })

    @count = @counts.primary_for_query(query)
    @grouped_data = Kaminari.paginate_array(data, total_count: @count).page(@page).per(@per_page)

    if query.taxa?
      @result_pages = @grouped_data.map do |datum|
        @pages[datum[:page_id]]
      end.compact

      @result_pages = PageSearchDecorator.decorate_collection(@result_pages)
    end
  end

  def search_common
    @page = params[:page] || 1
    @per_page = PER_PAGE
    Rails.logger.warn "&&TS Running search:"
    res = TraitBank.term_search(@query, {
      :page => @page,
      :per => @per_page,
    })
    data = res[:data]
    @raw_res = res[:raw_res].to_json
    build_query_for_display(res)
    ids = data.map { |t| t[:page_id] }.uniq
    # HERE IS THE IMPORTANT DB QUERY TO LOAD PAGES:
    pages = Page.where(:id => ids).with_hierarchy
    @pages = {}

    ids.each do |id|
      page = pages.find { |p| p.id == id }
      @pages[id] = page if page
    end

    # TODO: code review here. I think we're creating a lot of cruft we don't use.
    paginate_term_search_data(data, @query)
    @is_terms_search = true
    @resources = TraitBank.resources(data)
    @associations = build_associations(data)
    build_gbif_url(@count, pages, @query)
    data_viz_type(@query, @counts)
    render "search"
  end

  def redirect_no_format
    redirect_to term_search_results_path(term_query: tq_params)
  end

  def set_title
    @page_title = t("page_titles.traits.search")
  end

  def build_gbif_url(total_count, pages, query)
    if query.taxa? && total_count > 0 && Resource.gbif
      if total_count <= GBIF_LINK_LIMIT
        gbif_params = pages.collect do |p|
          pk = p.nodes.find_by(resource_id: Resource.gbif.id)&.resource_pk
          pk ? "taxon_key=#{pk}" : nil
        end.compact

        if gbif_params.any?
          @gbif_url = "#{GBIF_BASE_URL}?#{gbif_params.join("&")}"
        end
      elsif total_count <= GBIF_DOWNLOAD_LIMIT && GbifDownload.enabled_for_user?(current_user)
        @create_gbif_download_url = gbif_downloads_create_path(term_query: query.to_params)
      end
    end
  end

  def data_viz_type(query, counts)
    if TraitBank::Stats.check_query_valid_for_counts(query).valid
      @data_viz_type = :bar
    elsif TraitBank::Stats.check_query_valid_for_histogram(query, counts.primary_for_query(query)).valid
      @data_viz_type = :hist
    elsif TraitBank::Stats.check_query_valid_for_sankey(query).valid
      @data_viz_type = :sankey
    end
  end

  def set_view_type
    if params[:view].present? && VIEW_TYPES.include?(params[:view])
      @view_type = params[:view]
      session["ts_view_type"] = @view_type
    else
      @view_type = session["ts_view_type"] || "list"
    end
  end

  private
  def build_query_for_display(tb_res)
    query = tb_res[:raw_query].gsub(/^\ +/, '') # get rid of leading whitespace

    tb_res[:params].each do |k, v|
      val = v.is_a?(String) ? "\"#{v}\"" : v
      query = query.gsub("$#{k}", val.to_s)
    end

    @raw_query = query
  end
end
