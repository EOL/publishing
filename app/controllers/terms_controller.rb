class TermsController < ApplicationController
  helper :traits
  protect_from_forgery except: :clade_filter

  def show
    @term = TraitBank.term_as_hash(params[:uri])
    @page_title = @term[:name].titleize
    @object = params[:object]
    @page = params[:page]
    @per_page = 100 # TODO: config this or make it dynamic...
    @clade = params[:clade] ? Page.find(params[:clade]) : nil
    options = {
      page: @page, per: @per_page, sort: params[:sort],
      sort_dir: params[:sort_dir],
      clade: @clade.try(:id)
    }
    traits = @object ?
      TraitBank.by_object_term_uri(@term[:uri], options) :
      TraitBank.by_predicate(@term[:uri], options)
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: traits.map { |t| t[:page_id] }).
      includes(:medium, :native_node, :preferred_vernaculars)
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

  def predicate_glossary
    @count = TraitBank.predicate_glossary_count
    glossary
  end

  def object_term_glossary
    @count = TraitBank.object_term_glossary_count
    glossary
  end

  def units_glossary
    @count = TraitBank.units_glossary_count
    glossary
  end

  def paginate_traits(traits)
    @count = @object ?
      TraitBank.by_object_term_count(@term[:uri], clade: params[:clade]) :
      TraitBank.by_predicate_count(@term[:uri], clade: params[:clade])
    @grouped_traits = Kaminari.paginate_array(traits, total_count: @count).
      page(@page).per(@per_page)
  end

private

  def glossary
    @per_page = Rails.configuration.data_glossary_page_size
    @page = params[:page] || 1
    if params[:reindex] && is_admin?
      TraitBank.clear_caches
      lim = (@count / @per_page.to_f).ceil
      (0..lim+10).each do |index|
        expire_fragment("term/glossary/#{index}")
      end
    end
    @glossary = Kaminari.paginate_array(
        TraitBank.send(params[:action], @page, @per_page), total_count: @count
      ).page(@page).per(@per_page)
  end
end
