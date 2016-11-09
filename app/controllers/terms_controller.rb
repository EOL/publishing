class TermsController < ApplicationController
  helper :traits

  def show
    @term = TraitBank.term_as_hash(params[:uri])
    traits = TraitBank.by_predicate(@term[:uri], sort: params[:sort], sort_dir: params[:sort_dir])
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: traits.map { |t| t[:page_id] }).preloaded
    # Make a dictionary of pages:
    @pages = {}
    pages.each { |page| @pages[page.id] = page }
    # Make a glossary:
    @glossary = TraitBank.glossary(traits)
    @resources = TraitBank.resources(traits)

    @grouped_traits = Kaminari.paginate_array(traits).page(params[:page])
  end
end
