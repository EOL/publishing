class CacheWarmer
  class << self
    def warm
      Page.warm_autocomplete
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
        # Using Curl so we hit the full stack. I am wimping out here and hard-coding the URL. Sorry. TODO: extract.
        `curl https://eol.org/search?q=#{CGI.escape(string)}`
        sleep(0.1) # Just to take a LITTLE stress off the system without taking too long...
      end
    end
  end
end
