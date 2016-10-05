class TermsController < ApplicationController
  def show
    @term = TraitBank.term_as_hash(params[:uri])
    @traits = TraitBank.by_predicate(@term[:uri])
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: @traits.map { |t| t[:page_id] }).preloaded
    # Make a dictionary of pages:
    @pages = {}
    pages.each { |page| @pages[page.id] = page }
    # Make a glossary:
    @glossary = TraitBank.glossary(@traits)
    @resources = TraitBank.resources(@traits)
  end
end
