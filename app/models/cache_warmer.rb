class CacheWarmer
  class << self
    def warm
      Page.warm_autocomplete
      TraitBank::Terms.warm_caches
      warm_full_searches
    end

    def warm_full_searches
      # Landmarks:
      node_ids = Node.where(resource_id: Resource.native.id, landmark: [1, 2]).pluck(:id)
      page_ids = Node.where(id: node_ids).pluck(:page_id)
      strings = Node.where(id: node_ids).pluck(:canonical_form)
      strings += Vernacular.where(is_preferred: true, page_id: page_ids).pluck(:string)
      # Top Species:
      species_ranks = Rank.where(treat_as: Rank.treat_as['r_species'])
      num_top_species = 2000
      node_ids = Node.where(resource_id: Resource.native.id, rank: species_ranks).joins(:page).order('pages.page_contents_count DESC').limit(num_top_species).pluck('nodes.id')
      page_ids = Node.where(id: node_ids).pluck(:page_id)
      strings += Node.where(id: node_ids).pluck(:canonical_form)
      strings += Vernacular.where(is_preferred: true, page_id: page_ids).pluck(:string)
      strings.uniq!
      # NOTE: at the time of this writing, I ended up with 21K names, here, so this is a LOT of work!
      strings.each do |string|
        # Yes, I am wimping out by calling curl. TODO: We should extract the search code into a class and call it.
        `curl localhost:3000/search_results?q=#{CGI.escape(string)}`
        sleep(0.1) # Just to take a LITTLE stress off the system without taking too long...
      end
    end
  end
end
