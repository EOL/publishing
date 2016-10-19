# Confusingly, this is actually a controller for Uri (q.v.), but we want it
# exposed as "trait", because that's ultimately what it represents. Thus the
# name.
class TraitsController < ApplicationController
  protect_from_forgery except: :clade_filter
      
  def show
    @uri = Uri.find(params[:id])
    @traits ||= TraitBank.by_predicate(@uri.uri)
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: @traits.map { |t| t[:page_id] }).preloaded
    # Make a dictionary of pages:
    @pages = {}
    pages.each { |page| @pages[page.id] = page }
    # Make a glossary:
    @glossary = TraitBank.glossary(@traits)
    @resources = TraitBank.resources(@traits)
  end
  
  def clade_filter
    pages = {}
    debugger
    solr_matched_clade = Page.search {fulltext params[:clade_name]}.results.first
    #for convention sake
    if solr_matched_clade
      pages[solr_matched_clade.id] = solr_matched_clade
      traits = TraitBank.get_clade_traits(solr_matched_clade.id, params[:uri_id])
      glossary = TraitBank.glossary(traits)
      resources = TraitBank.resources(traits)
    end
    respond_to do |fmt|
      fmt.html
      fmt.js do
        render partial: 'traits_table', locals: {:traits => traits ? traits : [], :glossary => glossary, :pages => pages, :resources => resources}
      end
    end
  end
end
