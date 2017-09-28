class TermsController < ApplicationController
  helper :data
  protect_from_forgery except: :clade_filter

  def index
    @count = TraitBank::Terms.count
    glossary("full_glossary")
  end

  def show
    # The whole "object" thing is lame! Get rid of it entirely. Just change
    # which one you have, and if you have both, emphasize the predicate!
    @term = TraitBank.term_as_hash(params[:uri])
    @and_predicate = TraitBank.term_as_hash(params[:and_predicate])
    @and_object = TraitBank.term_as_hash(params[:and_object])
    @page_title = @term[:name].titleize
    @object = params[:object]
    @page = params[:page]
    @per_page = 100 # TODO: config this or make it dynamic...
    @species_list = params[:species_list]
    @clade = if params[:clade]
        if params[:clade] =~ /\A\d+\Z/
          Page.find(params[:clade])
        else
          # TODO: generalize this
          query = Page.autocomplete(params[:clade], limit: 1, load: true)
          params[:clade] = query.first.id
          query.first
        end
      else
        nil
      end
    options = {
      page: @page, per: @per_page, sort: params[:sort],
      sort_dir: params[:sort_dir], page_list: @species_list,
      clade: @clade.try(:id)
    }

    add_uri_to_options(options)

    respond_to do |fmt|
      fmt.html do
        data = TraitBank.term_search(options)
        # We want the results in this order:
        ids = data.map { |t| t[:page_id] }.uniq
        # TODO: a fast way to load pages with just summary info:
        pages = Page.where(id: ids).
          includes(:medium, :native_node, :preferred_vernaculars)
        # Make a dictionary of pages:
        @pages = {}
        ids.each do |id|
          page = pages.find { |p| p.id == id }
          @pages[id] = page if page
        end
        # Make a glossary:
        @resources = TraitBank.resources(data)
        paginate_data(data)
        get_associations
      end

      fmt.csv do
        data = TraitBank::DataDownload.term_search(options.merge(user_id: current_user.id))
        if data.is_a?(UserDownload)
          flash[:notice] = t("user_download.created", url: user_path(current_user))
          loc = params
          loc.delete(:format)
          redirect_to term_path(params)
        else
          send_data data,
            filename: "#{@term[:name]}-#{Date.today}.tsv"
        end
      end
    end
  end

  def predicate_glossary
    @count = TraitBank::Terms.predicate_glossary_count
    glossary(params[:action])
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

  def object_term_glossary
    @count = TraitBank::Terms.object_term_glossary_count
    glossary(params[:action])
  end

  def units_glossary
    @count = TraitBank::Terms.units_glossary_count
    glossary(params[:action])
  end

private

  def paginate_data(data)
    options = { clade: params[:clade], count: true }
    add_uri_to_options(options)
    @count = TraitBank.term_search(options)
    @grouped_data = Kaminari.paginate_array(data, total_count: @count).
      page(@page).per(@per_page)
  end

  def glossary(which)
    @per_page = params[:per_page] || Rails.configuration.data_glossary_page_size
    @page = params[:page] || 1
    query = params[:query]
    @per_page = 10 if query
    if params[:reindex] && is_admin?
      TraitBank::Admin.clear_caches
      lim = (@count / @per_page.to_f).ceil
      (0..lim+10).each do |index|
        expire_fragment("term/glossary/#{index}")
      end
    end
    @glossary = TraitBank::Terms.send(which, @page, @per_page, query)
    @glossary = Kaminari.paginate_array(@glossary, total_count: @count).
      page(@page).per(@per_page)
    respond_to do |fmt|
      fmt.html {}
      fmt.json { render json: @glossary }
    end
  end

  def get_associations
    @associations =
      begin
        ids = @grouped_data.map { |t| t[:object_page_id] }.compact.sort.uniq
        Page.where(id: ids).
          includes(:medium, :preferred_vernaculars, native_node: [:rank])
      end
  end
end
