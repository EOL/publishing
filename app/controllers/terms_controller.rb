class TermsController < ApplicationController
  helper :traits
  protect_from_forgery except: :clade_filter

  def show
    @term = TraitBank.term_as_hash(params[:uri])
    @page_title = @term[:name].titleize
    @object = params[:object]
    @page = params[:page]
    @per_page = 20 # TODO: config this or make it dynamic...
    options = {
      page: @page, per: @per_page, sort: params[:sort],
      sort_dir: params[:sort_dir]
    }
    traits = @object ?
      TraitBank.by_object_term_uri(@term[:uri], options) :
      TraitBank.by_predicate(@term[:uri], options)
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: traits.map { |t| t[:page_id] }).preloaded
    # Make a dictionary of pages:
    @pages = {}
    pages.each { |page| @pages[page.id] = page }
    # Make a glossary:
    @resources = TraitBank.resources(traits)
    paginate_traits(traits)
  end

  def glossary
    @per_page = Rails.configuration.data_glossary_page_size
    @page = params[:page] || 1
    @count = TraitBank.terms_count
    if params[:reindex] && is_admin?
      TraitBank.clear_caches
      @count = TraitBank.terms_count # May as well re-load this value!
      lim = (@count / @per_page.to_f).ceil
      (0..lim).each do |index|
        expire_fragment("term/glossary/#{index}")
      end
    end
    @glossary = Kaminari.paginate_array(
        TraitBank.full_glossary(@page, @per_page), total_count: @count
      ).page(@page).per(@per_page)
  end

  def paginate_traits(traits)
    @count = @object ?
      TraitBank.by_object_term_count(@term[:uri]) :
      TraitBank.by_predicate_count(@term[:uri])
    @grouped_traits = Kaminari.paginate_array(traits, total_count: @count).
      page(@page).per(@per_page)
  end

  def clade_filter
    pages = {}
    solr_matched_clade = Page.search {fulltext params[:clade_name]}.results.first
    #for convention sake
    if solr_matched_clade
      pages[solr_matched_clade.id] = solr_matched_clade
      traits = TraitBank.get_clade_traits(solr_matched_clade.id, params[:uri])
      @glossary = TraitBank.glossary(traits)
      @resources = TraitBank.resources(traits)
    end
    respond_to do |fmt|
      fmt.html
      fmt.js do
        render partial: 'traits_table', locals: {:traits => traits ? paginate_traits(traits) : [],
          :glossary => @glossary, :pages => pages, :resources => @resources}
      end
    end
  end
end
