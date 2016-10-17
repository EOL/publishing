# Confusingly, this is actually a controller for Uri (q.v.), but we want it
# exposed as "trait", because that's ultimately what it represents. Thus the
# name.
class TraitsController < ApplicationController
  def show
    @uri = Uri.find(params[:id])
    traits = TraitBank.by_predicate(@uri.uri)
    # @traits = Kaminari.paginate_array(@traits).page(params[:page])
    
    
    # TODO: a fast way to load pages with just summary info:
    pages = Page.where(id: traits.map { |t| t[:page_id] }).preloaded
    # Make a dictionary of pages:
    @pages = {}
    pages.each { |page| @pages[page.id] = page }
    # Make a glossary:
    @glossary = TraitBank.glossary(traits)
    @resources = TraitBank.resources(traits)
    
    group_traits = traits.group_by { |t| t[:page_id] }
    keys = group_traits.keys.sort 
    @grouped_traits = []
    keys.each do |page_id|
      @grouped_traits << TraitBank.sort(group_traits[page_id], @glossary)     
    end 
    @grouped_traits = Kaminari.paginate_array(@grouped_traits.flatten).page(params[:page])
  end
end
