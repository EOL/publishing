class BriefSummary
  class PageDecorator
    delegate_missing_to :@page
    
    def initialize(page)
      @page = page
    end

    def family_or_above?
      @page.rank&.treat_as.present? &&
      Rank.treat_as[@page.rank.treat_as] <= Rank.treat_as[:r_family]
    end

    def below_family?
      @page.rank&.treat_as.present? && 
      Rank.treat_as[@page.rank.treat_as] > Rank.treat_as[:r_family]
    end

    # A1: Use the landmark with value 1 that is the closest ancestor of the species. Use the English vernacular name, if
    # available, else use the canonical.
    def a1
      return @a1_link if @a1_link
      @a1 ||= @page.ancestors.reverse.find { |a| a && a.minimal? }
      return nil if @a1.nil?
      a1_name = @a1.page&.vernacular&.string || @a1.vernacular
      # Vernacular sometimes lists things (e.g.: "wasps, bees, and ants"), and that doesn't work. Fix:
      a1_name = nil if a1_name&.match(' and ')
      a1_name ||= @a1.canonical
      @a1_link = @a1.page ? view.link_to(a1_name, @a1.page) : a1_name
      # A1: There will be nodes in the dynamic hierarchy that will be flagged as A1 taxa. If there are vernacularNames
      # associated with the page of such a taxon, use the preferred vernacularName.  If not use the scientificName from
      # dynamic hierarchy. If the name starts with a vowel, it should be preceded by an, if not it should be preceded by
      # a.
    end

    # A2: Use the name of the family (i.e., not a landmark taxon) of the species. Use the English vernacular name, if
    # available, else use the canonical. -- Complication: some family vernaculars have the word "family" in then, e.g.,
    # Rosaceae is the rose family. In that case, the vernacular would make for a very awkward sentence. It would be great
    # if we could implement a rule, use the English vernacular, if available, unless it has the string "family" in it.
    def a2
      return @a2_link if @a2_link
      return nil if a2_node.nil?
      a2_name = a2_node.page&.vernacular&.string || a2_node.vernacular
      a2_name = nil if a2_name && a2_name =~ /family/i
      a2_name = nil if a2_name && a2_name =~ / and /i
      a2_name ||= a2_node.canonical_form
      @a2_link = a2_node.page ? view.link_to(a2_name, a2_node.page) : a2_name
    end

    def a2_node
      @a2_node ||= @page.ancestors.reverse.compact.find { |a| Rank.family_ids.include?(a.rank_id) }
    end

    # If the species has a value for measurement type http://purl.obolibrary.org/obo/GAZ_00000071, insert a Distribution
    # Sentence:  "It is found in [G1]."
    def g1
      @g1 ||= values_to_sentence([TermNode.find_by(uri: 'http://purl.obolibrary.org/obo/GAZ_00000071')])
    end
  end
end
