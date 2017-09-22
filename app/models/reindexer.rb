module Reindexer
  class << self
    # e.g.: fix_common_names("Plantae", "plants")
    def fix_common_names(scientific, common)

      nodes = Node.where(scientific_name: scientific)
      if nodes.count == 0
        puts "There is currently no \"#{scientific}\" in the database."
        return nil
      end
      node = nodes.first

      page = Page.where(id: node.page_id).first_or_create do |p|
        p.id = node.page_id
        p.native_node_id = node.id
      end

      nodes.each do |plant|
        cmn = Vernacular.where(string: common, node_id: node.id,
          page_id: page.id, language_id: Language.english.id).first_or_create do |n|
            n.string = common
            n.node_id = node.id
            n.page_id = page.id
            n.language_id = Language.english.id
            n.is_preferred = true
            n.is_preferred_by_resource = true
          end
        node.vernaculars << cmn
      end
    end

    def fix_all_counter_culture_counts
      [CollectionAssociation, Node, PageContent, ScientificName, Vernacular].
        each do |k|
          k.counter_culture_fix_counts
        end
    end

    def score_richness
      score_richness_for_pages(Page.where("id IS NOT NULL"))
    end

    def score_richness_for_pages(pages)
      puts "#{Page.count} pages"
      start_time = Time.now
      count = 0
      pages.find_each do |page|
        page.score_richness
        score = page.richness
        count += 1
        print "." if count % 1000 == 0
      end
      puts "\nDone. Took #{((Time.now - start_time) / 1.minute).round} minutes."
    end
  end
end
