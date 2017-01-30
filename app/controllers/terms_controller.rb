class TermsController < ApplicationController
  helper :traits
  protect_from_forgery except: :clade_filter
  
  def show
    @term = TraitBank.term_as_hash(params[:uri])
    traits = TraitBank.by_predicate(@term[:uri], sort: params[:sort], sort_dir: params[:sort_dir], clade_name: params[:clade_name])
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
  
  # def clade_filter
    # pages = {}
    # solr_matched_clade = Page.search {fulltext params[:clade_name]}.results.first
    # #for convention sake
# 
    # respond_to do |fmt|
      # fmt.html
      # fmt.json do
        # render json: JSON.pretty_generate(@pages.results.as_json(
          # except: :native_node_id,
          # methods: :scientific_name,
          # include: {
            # preferred_vernaculars: { only: [:string],
              # include: { language: { only: :code } } },
            # # NOTE I'm excluding a lot more for search than you would want for
            # # the basic page json:
            # top_image: { only: [ :id, :guid, :owner, :name ],
              # methods: [:small_icon_url, :medium_icon_url],
              # include: { provider: { only: [:id, :name] },
                # license: { only: [:id, :name, :icon_url] } } }
          # }
        # ))
      # end
      # fmt.js do
        # render partial: 'traits_table', locals: {:traits => traits ? paginate_traits(traits) : [], 
          # :glossary => @glossary, :pages => pages, :resources => @resources}
      # end
    # end
  # end
end
