class TermsController < ApplicationController
  helper :data
  protect_from_forgery except: :clade_filter

  def show
    @term = TraitBank.term_as_hash(params[:uri])
    @and_object = TraitBank.term_as_hash(params[:and_object])
    @page_title = @term[:name].titleize
    @object = params[:object]
    @page = params[:page]
    @per_page = 100 # TODO: config this or make it dynamic...
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
      sort_dir: params[:sort_dir],
      clade: @clade.try(:id)
    }

    add_uri_to_options(options)

    respond_to do |fmt|
      fmt.html do
        data = TraitBank.term_search(options)
        # TODO: a fast way to load pages with just summary info:
        pages = Page.where(id: data.map { |t| t[:page_id] }.uniq).
          includes(:medium, :native_node, :preferred_vernaculars)
        # Make a dictionary of pages:
        @pages = {}
        pages.each { |page| @pages[page.id] = page }
        # Make a glossary:
        @resources = TraitBank.resources(data)
        @species_list = params[:species_list]
        paginate_data(data)
        get_associations
      end

      fmt.csv do
        options[:meta] = true
        data = TraitBank.term_search(options)
        send_data TraitBank::DataDownload.to_arrays(data),
          filename: "#{@term[:name]}-#{Date.today}.tsv"
      end
    end
  end

  def glossary
    @per_page = Rails.configuration.data_glossary_page_size
    @page = params[:page] || 1
    @count = TraitBank::Terms.count
    if params[:reindex] && is_admin?
      TraitBank::Admin.clear_caches
      @count = TraitBank::Terms.count # May as well re-load this value!
      lim = (@count / @per_page.to_f).ceil
      (0..lim).each do |index|
        expire_fragment("term/glossary/#{index}")
      end
    end
    @glossary = Kaminari.paginate_array(
        TraitBank::Terms.full_glossary(@page, @per_page), total_count: @count
      ).page(@page).per(@per_page)
  end

  def predicate_glossary
    @count = TraitBank::Terms.predicate_glossary_count
    glossary
  end

  def add_uri_to_options(options)
    if @object
      options[:predicate] = nil # TODO
      options[:object_term] = @and_object ?
        [@term[:uri], @and_object[:uri]] :
        @term[:uri]
    else
      options[:predicate] = @term[:uri]
      options[:object_term] = @and_object && @and_object[:uri]
    end
  end

  def object_term_glossary
    @count = TraitBank::Terms.object_term_glossary_count
    glossary
  end

  def units_glossary
    @count = TraitBank::Terms.units_glossary_count
    glossary
  end

private

  def paginate_data(data)
    options = { clade: params[:clade], count: true }
    add_uri_to_options(options)
    @count = TraitBank.term_search(options)
    @grouped_data = Kaminari.paginate_array(data, total_count: @count).
      page(@page).per(@per_page)
  end

  def glossary
    @per_page = Rails.configuration.data_glossary_page_size
    @page = params[:page] || 1
    if params[:reindex] && is_admin?
      TraitBank::Admin.clear_caches
      lim = (@count / @per_page.to_f).ceil
      (0..lim+10).each do |index|
        expire_fragment("term/glossary/#{index}")
      end
    end
    @glossary = Kaminari.paginate_array(
        TraitBank::Terms.send(params[:action], @page, @per_page), total_count: @count
      ).page(@page).per(@per_page)
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
