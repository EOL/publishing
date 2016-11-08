class TermsController < ApplicationController
  
  protect_from_forgery except: :clade_filter
  
  def show
    @term = TraitBank.term_as_hash(params[:uri])
    traits = TraitBank.by_predicate(@term[:uri])
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: traits.map { |t| t[:page_id] }).preloaded
    # Make a dictionary of pages:
    @pages = {}
    pages.each { |page| @pages[page.id] = page }
    # Make a glossary:
    @glossary = TraitBank.glossary(traits)
    @resources = TraitBank.resources(traits)
    paginate_traits(traits)    
  end
  
  def paginate_traits(traits)
    group_traits = traits.group_by { |t| t[:page_id] }
    keys = group_traits.keys.sort
    @grouped_traits = []
    keys.each do |page_id|
      @grouped_traits << TraitBank.sort(group_traits[page_id])
    end
    @grouped_traits = Kaminari.paginate_array(@grouped_traits.flatten).
      page(params[:page])
  end
  
  def clade_filter
    pages = {}
    solr_matched_clade = Page.search {fulltext params[:clade_name]}.results.first
    #for convention sake
    if solr_matched_clade
      pages[solr_matched_clade.id] = solr_matched_clade
      traits = TraitBank.get_clade_traits(solr_matched_clade.id, params[:uri])
      glossary = TraitBank.glossary(traits)
      resources = TraitBank.resources(traits)
    end
    respond_to do |fmt|
      fmt.html
      fmt.js do
        render partial: 'traits_table', locals: {:traits => traits ? paginate_traits(traits) : [], :glossary => glossary, :pages => pages, :resources => resources}
      end
    end
  end
end
