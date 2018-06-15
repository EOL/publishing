# Implementation of https://docs.google.com/document/d/1F5hGZv93_BUUde6gEciJ27ePd8_5BFg8ffqDQcrO4t8/edit
class BriefSummary
  def initialize(page)
    @page = page
    @sentences = []
    @a1_name = nil
    @a2_node = nil
    @a2_name = nil
  end

  def english
    return "The brief summary is in development. Please check back later."
    if is_species?
      species
    elsif is_genus?
      genus
    else is_family?
      family
    end
  end

  # Landmarks are documented here https://github.com/EOL/eol_website/issues/5
  # STAGING [15] pry(main)> Node.landmarks => {"no_landmark"=>0, "minimal"=>1, "abbreviated"=>2, "extended"=>3,
  # "full"=>4} For P. lotor, there's no "full", the "extended" is Tetropoda, "abbreviated" is Carnivora, "minimal" is
  # Mammalia. JR believes this is usually a Class, but for different types of life, different ranks may make more sense.
  def a1
    return @a1_name if @a1_name
    @a1 ||= page.ancestors.reverse.find { |a| a.minimal? }
    # A1: There will be nodes in the dynamic hierarchy that will be flagged as A1 taxa. If there are vernacularNames
    # associated with the page of such a taxon, use the preferred vernacularName.  If not use the scientificName from
    # dynamic hierarchy. If the name starts with a vowel, it should be preceded by an, if not it should be preceded by
    # a.
  end

  # A2: There will be nodes in the dynamic hierarchy that will be flagged as A2 taxa. Use the scientificName from
  # dynamic hierarchy. JR believes this should, roughly, be the family (note that for certain types of life, different
  # ranks make more sense). TODO: do they really mean "scientific name"? Or canonical form? I'm assuming the latter.
  def a2
    return @a2_name if @a2_name
    return '[UNKNOWN A2]' if a2_node.nil?
    @a2_name = a2_node.canonical_form
  end

  def a2_node
    @a2_node ||= page.ancestors.reverse.find { |a| a.abbreviated? }
  end

  def rank_of_a2
    a2_node.rank&.name || '[UNKNOWN RANK OF A2]'
  end

  # Geographic data (G1) will initially be sourced from a pair of measurement types:
  # http://rs.tdwg.org/dwc/terms/continent, http://rs.tdwg.org/dwc/terms/waterBody (not yet available, but for testing
  # you can use: http://rs.tdwg.org/ontology/voc/SPMInfoItems#Distribution) Some taxa may have multiple values, and
  # there may be some that have both continent and waterBody values. If there is no continent or waterBody information
  # available, omit the second sentence.
  # TODO: these URIs are likely to change, check with JH again when you get back to these.
  def g1
    @g1 ||= values_to_sentence(['http://rs.tdwg.org/dwc/terms/continent', 'http://rs.tdwg.org/dwc/terms/waterBody', 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Distribution'])
  end

  def species
    # taxonomy sentence:
    # TODO: this assumes perfect coverage of A1 and A2 for all species, which is a bad idea. Have contingencies.
    @sentences << "#{name_clause} is #{a_or_an(something)} #{a1} in the #{rank_of_a2} #{a2}."
    # If the species [is extinct], insert an extinction status sentence between the taxonomy sentence
    # and the distribution sentence. extinction status sentence: This species is extinct.
    @sentences << 'This species is extinct.' if is_it_extinct?
    # If the species [is marine], insert an environment sentence between the taxonomy sentence and the distribution
    # sentence. environment sentence: "It is marine." If the species is both marine and extinct, insert both the
    # extinction status sentence and the environment sentence, with the extinction status sentence first.
    @sentences << 'It is marine.' if is_it_marine?
    # Distribution sentence: It is found in [G1].
    @sentences << "It is found in #{g1}." if g1
  end

  def genus
    @sentences << "#{name_clause} is a family of [A1]."
    # Number of species sentence: It has [xx] species.
    # Distribution sentence: [name] are found in [G1].
    #
    # For families, we add a number of species sentence between the taxonomy sentence and the distribution sentence.
    #
    # If the family has value http://eol.org/schema/terms/extinct for measurement type http://eol.org/schema/terms/ExtinctionStatus, insert an extinction status sentence between the taxonomy sentence and the number of species sentence:
    #
    # extinction status sentence: This family is extinct.
    #
    # Examples:
    # Agaricaceae (Gilled Fungi) is a family of Fungi. It has 5000 species. Agaricaceae are found in North America, South America and Asia.
    #
    # Tyrannosauridae is a family of Dinosaurs. This family is extinct. It has 1 species. Tyrannosauridae are found in North America.
  end

  def family
    @sentences << "#{name_clause} is a family of [A1]."
    # Number of species sentence: It has [xx] species.
    # Distribution sentence: [name] are found in [G1].
    #
    # For families, we add a number of species sentence between the taxonomy sentence and the distribution sentence.
    #
    # If the family has value http://eol.org/schema/terms/extinct for measurement type http://eol.org/schema/terms/ExtinctionStatus, insert an extinction status sentence between the taxonomy sentence and the number of species sentence:
    #
    # extinction status sentence: This family is extinct.
    #
    # Examples:
    # Agaricaceae (Gilled Fungi) is a family of Fungi. It has 5000 species. Agaricaceae are found in North America, South America and Asia.
    #
    # Tyrannosauridae is a family of Dinosaurs. This family is extinct. It has 1 species. Tyrannosauridae are found in North America.
  end

  def name_clause
    if page.name == page.scientific_name
      page.name
    elsif page.scientific_name =~ /#{page.name}/
      # Sometimes the "name" is part of the scientific name, and it looks really weird to double up.
      page.scientific_name
    else
      "#{page.scientific_name} (#{page.name})"
    end
  end

  # ...has a value with parent http://purl.obolibrary.org/obo/ENVO_00000447 for measurement type
  # http://eol.org/schema/terms/Habitat
  def is_it_marine?
    if @page.has_checked_marine?
      @page.is_marine?
    else
      marine =
        has_data(predicates: ['http://eol.org/schema/terms/Habitat'],
                 values: ['http://purl.obolibrary.org/obo/ENVO_00000447'])
      @page.update_attribute(:has_checked_marine, true)
      @page.update_attribute(:is_marine, marine)
      marine
    end
  end

  def has_data(options)
    recs = []
    gather_terms(options[:predicates]).each do |term|
      recs += @page.grouped_data[term]
    end
    recs.compact!
    return nil if recs.empty?
    values = gather_terms(options[:values])
    return nil if values.empty?
    return true if recs.any? { |r| r[:object_term] && values.inlcude?(r[:object_term][:uri]) }
    return false
  end

  def gather_terms(uris)
    terms = []
    Array(uris).each { |uri| terms += TraitBank.descendants_of_term(uri) }
    terms.compact
  end

  # has value http://eol.org/schema/terms/extinct for measurement type http://eol.org/schema/terms/ExtinctionStatus
  def is_it_extinct?
    if @page.has_checked_extinct?
      @page.is_extinct?
    else
      # NOTE: this relies on #displayed_extinction_data ONLY returning an "exinct" record. ...which, as of this writing,
      # it is designed to do.
      @page.update_attribute(:has_checked_extinct, true)
      if @page.displayed_extinction_data # TODO: this method doesn't check descendants yet.
        @page.update_attribute(:is_extinct, true)
        return true
      else
        @page.update_attribute(:is_extinct, false)
        return false
      end
    end
  end

  # Print all values, separated by commas, with “and” instead of comma before the last item in the list.
  def values_to_sentence(uris)
    values = []
    uris.flat_map { |uri| gather_terms(uri) }.each do |term|
      @page.grouped_data[term].each do |trait|
        if trait.key?(:object_term)
          values << trait[:object_term][:name]
        else
          values << trait[:literal]
        end
      end
    end
    values.any? ? values.uniq.to_sentence : nil
  end

  def old_for(page)
    group = nearest_landmark(page)
    return "" unless group
    my_rank = page.rank.try(:name) || "taxon"
    node = page.native_node || page.nodes.first
    ancestors = node.ancestors.select { |a| a.has_breadcrumb? }
    # taxonomy sentence...
    str = name_clause
    # A1: There will be nodes in the dynamic hierarchy that will be flagged as
    # A1 taxa. If there are vernacularNames associated with the page of such a
    # taxon, use the preferred vernacularName. If not use the scientificName
    # from dynamic hierarchy. If the name starts with a vowel, it should be
    # preceded by an, if not it should be preceded by a.
    # A2: There will be nodes in the dynamic hierarchy that will be flagged as
    # A2 taxa. Use the scientificName from dynamic hierarchy.
    if true # TEMP fix for broken stuff below:
      str += " is in the group #{group}. "
    else # THIS STUFF BROKE WITH THE LATEST DYNAMIC HIERARCHY. We'll fix it later.
      if ancestors[0]
        if is_family?(page)
          # [name] ([common name]) is a family of [A1].
          str += " is #{a_or_an(my_rank)} of #{ancestors[0].name}."
        elsif is_higher_level_clade?(page) && ancestors[-2]
          # [name] ([common name]) is a genus in the [A1] [rank] [A2].
          str += " is #{a_or_an(my_rank)} in the #{ancestors[0].name} #{rank_or_clade(ancestors[-2])} #{ancestors[-2].scientific_name}."
        else
          # [name] ([common name]) is #{a_or_an(something)} [A1] in the [rank] [A2].
          str += " #{is_or_are(page)} #{a_or_an(ancestors[0].name.singularize)}"
          if ancestors[-2] && ancestors[-2] != ancestors[0]
            str += " in the #{rank_or_clade(ancestors[-2])} #{ancestors[-2].scientific_name}"
          end
          str += "."
        end
      end
    end
    # Number of species sentence:
    if is_higher_level_clade?(page)
      count = page.species_count
      str += " It has #{count} species."
    end
    # Extinction status sentence:
    if page.is_it_extinct?
      str += " This #{my_rank} is extinct."
    end
    # Environment sentence:
    if ! is_higher_level_clade?(page) && page.is_it_marine?
      str += " It is marine."
    end
    # Distribution sentence:
    unless page.habitats.blank?
      str += " #{page.scientific_name} #{is_or_are(page)} found in #{page.habitats.split(", ").sort.to_sentence}."
      # TEMP: SKIP for now...
      # if is_family?(page)
      #   # Do nothing.
      # elsif is_genus?(page)
      #   str += " #{page.scientific_name} #{is_or_are(page)} found in #{page.habitats.split(", ").sort.to_sentence}."
      # else
      #   str += " It is found in #{page.habitats.split(", ").sort.to_sentence}."
      # end
    end
    bucket = page.id.to_s[0]
    summaries = Rails.cache.read("constructed_summaries/#{bucket}") || []
    summaries << page.id
    Rails.cache.write("constructed_summaries/#{bucket}", summaries)
    str
  end

  def nearest_landmark(page)
    return unless page.native_node
    page.ancestors.reverse.compact.find { |node| node.use_breadcrumb? }&.canonical_form
  end

  def is_higher_level_clade?(page)
    page.rank && page.rank.respond_to?(:treat_as) &&
      ["r_genus", "r_family"].include?(page.rank.treat_as)
  end

  # TODO: it would be nice to make these into a module included by the Page
  # class.
  def is_family?(page)
    page.rank && page.rank.respond_to?(:treat_as) &&
      page.rank.treat_as == "r_family"
  end

  def is_genus?(page)
    page.rank && page.rank.respond_to?(:treat_as) &&
      page.rank.treat_as == "r_genus"
  end

  def rank_or_clade(node)
    node.rank.try(:name) || "clade"
  end

  def is_or_are(page)
    page.scientific_name =~ /\s[a-z]/ ? "is" : "are"
  end

  # Note: this does not always work (e.g.: "an unicorn")
  def a_or_an(word)
    %w(a e i o u).include?(word[0].downcase) ? "an #{word}" : "a #{word}"
  end
end
