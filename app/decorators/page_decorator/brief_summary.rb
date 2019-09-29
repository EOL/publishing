# At the time of writing, this was an implementation of
# https://github.com/EOL/eol_website/issues/5#issuecomment-397708511 and
# https://github.com/EOL/eol_website/issues/5#issuecomment-402848623
require "set"

class PageDecorator
  class BriefSummary
    attr_accessor :view

    FLOWER_VISITOR_LIMIT = 4

    ANC_PAGE = Struct.new(:id, :name)

    # XXX: This needs to be fixed ASAP. We shouldn't be relying on page ids to identify these, as those could change.
    ABOVE_FAMILY_ANC_PAGES = [
      ANC_PAGE.new(1, "Animals"),
      ANC_PAGE.new(288, "Bacteria"),
      ANC_PAGE.new(42430800, "Plants"),
      ANC_PAGE.new(5559, "Fungi"),
      ANC_PAGE.new(7920, "Archaea"),
      ANC_PAGE.new(5006, "Viruses"),
      ANC_PAGE.new(2915041, "Amoebas")
    ]

    def initialize(page, view)
      @page = page
      @view = view
      @sentences = []
      @terms = []
    end

    # NOTE: this will only work for these specific ranks (in the DWH). This is by design (for the time-being). # NOTE: I'm
    # putting species last because it is the most likely to trigger a false-positive. :|
    def english
      # There's really nothing to do if there's no minimal ancestor:
      if is_above_family?
        above_family
      else
        if !a1.nil?
          if is_family?
            family
          elsif is_genus?
            genus
          elsif is_species?
            species
          end
        end
      end

      landmark_children
      plant_description_sentence
      flower_visitor_sentence

      if !is_family? && !is_genus?
        behavioral_sentence
        lifespan_sentence
      end

      Result.new(@sentences.join(' '), @terms)
    end

    private
      LandmarkChildLimit = 3
      Result = Struct.new(:sentence, :terms)
      ResultTerm = Struct.new(:pred_uri, :obj, :source, :toggle_selector)

      IUCN_URIS = Set[
        Eol::Uris::Iucn.en, 
        Eol::Uris::Iucn.cr, 
        Eol::Uris::Iucn.ew, 
        Eol::Uris::Iucn.nt, 
        Eol::Uris::Iucn.vu
      ]

      def is_above_family?
        @page.rank.present? && Rank.treat_as[@page.rank.treat_as] < Rank.treat_as[:r_family]
      end

      def above_family
        anc_page_ids = Set.new(@page.node_ancestors.includes(:ancestor).pluck("page_id"))

        anc = ABOVE_FAMILY_ANC_PAGES.find do |a|
          anc_page_ids.include?(a.id)
        end

        if anc
          @sentences << "#{@page.name} is a group of #{view.link_to(anc.name, view.page_path(anc.id))}."
        end

        first_appearance_trait = first_trait_for_pred_uri(Eol::Uris.fossil_first)

        if first_appearance_trait
          term_sentence("This group has been around since the %s", first_appearance_trait)
        end
      end

      # [name clause] is a[n] [A1] in the family [A2].
      def species
        # taxonomy sentence:
        # TODO: this assumes perfect coverage of A1 and A2 for all species, which is a bad idea. Have contingencies.
        what = a1
        family = a2
        species_parts = []

        if match = growth_habit_matches.by_type(:x_species)
          species_parts << trait_sentence_part(
            "#{name_clause} is "\
            "#{a_or_an(match.trait[:object_term][:name])} %s "\
            "species of #{what}",
            match.trait
          )
        elsif match = growth_habit_matches.by_type(:species_of_x)
          species_parts << trait_sentence_part(
            "#{name_clause} is a species of %s",
            match.trait
          )
        else
          species_parts << "#{name_clause} is a species of #{what}"
        end

        if family
          species_parts << " in the family #{a2}"
        end

        if match = growth_habit_matches.by_type(:and_a_x)
          species_parts << trait_sentence_part(
            ", and #{a_or_an(match.trait[:object_term][:name])} %s",
            match.trait
          )
        elsif match = growth_habit_matches.by_type(:x_growth_habit)
          species_parts << trait_sentence_part(
            ", with #{a_or_an(match.trait[:object_term][:name])} %s growth habit",
            match.trait
          )
        end

        species_parts << "."
        @sentences << species_parts.join("")

        if is_it_extinct?
          term_sentence("This species is %s.", "extinct", Eol::Uris.extinction, Eol::Uris.extinct)
        else
          conservation_sentence
        end

        # If the species [is extinct], insert an extinction status sentence between the taxonomy sentence
        # and the distribution sentence. extinction status sentence: This species is extinct.

        # If the species [is marine], insert an environment sentence between the taxonomy sentence and the distribution
        # sentence. environment sentence: "It is marine." If the species is both marine and extinct, insert both the
        # extinction status sentence and the environment sentence, with the extinction status sentence first.
        term_sentence("It is found in %s.", "marine habitat", Eol::Uris.habitat_includes, Eol::Uris.marine) if is_it_marine?

        # Distribution sentence: It is found in [G1].
        @sentences << "It is found in #{g1}." if g1
      end

      # Iterate over all growth habit objects and get the first for which 
      # GrowthHabitGroup.match returns a result, or nil if none do. The result
      # of this operation is cached.
      def growth_habit_matches
        return @growth_habit_matches if @growth_habit_matched

        terms = gather_terms(Eol::Uris.growth_habit)
        traits = terms.map do |term|
          @page.grouped_data[term] || []
        end.flatten

        @growth_habit_matched = true
        @growth_habit_matches = GrowthHabitGroup.match_all(traits)
      end

      # [name clause] is a genus in the [A1] family [A2].
      #
      def genus
        family = a2
        if family
          @sentences << "#{name_clause} is a genus of #{a1} in the family #{family}."
        else
          @sentences << "#{name_clause} is a family of #{a1}."
        end
        # We may have a few genera that don't have a family in their ancestry. In those cases, shorten the taxonomy sentence:
        # [name clause] is a genus in the [A1]
      end

      # [name clause] is a family of [A1].
      #
      # This will look a little funny for those families with "family" vernaculars, but I think it's still acceptable, e.g.,
      # Rosaceae (rose family) is a family of plants.
      def family
        @sentences << "#{name_clause} is a family of #{a1}."
      end

      def landmark_children
        children = @page.native_node&.landmark_children(LandmarkChildLimit) || []

        if children.any?
          taxa_links = children.map { |c| view.link_to(c.page.vernacular_or_canonical, c.page) }
          @sentences << "#{name_clause} includes groups like #{taxa_links.to_sentence}."
        end
      end

      def behavioral_sentence
        circadian = first_trait_for_obj_uris(
          Eol::Uris.nocturnal,
          Eol::Uris.diurnal,
          Eol::Uris.crepuscular
        )
        solitary = first_trait_for_obj_uris(Eol::Uris.solitary)
        trophic = first_trait_for_pred_uri(Eol::Uris.trophic_level)
        circadian_part = trait_sentence_part("%s", circadian) if circadian
        solitary_part = trait_sentence_part("%s", solitary) if solitary
        trophic_part = trait_sentence_part("%s", trophic) if trophic
        begin_parts = [solitary_part, circadian_part].compact
        sentence = nil

        if begin_parts.any?
          if trophic_part
            begin_part = begin_parts.join(", ")
            sentence = "It is #{a_or_an(begin_part)} #{begin_part} #{trophic_part}."
          else
            sentence = "It is #{begin_parts.join(" and ")}."
          end
        elsif trophic_part
          sentence = "It is #{a_or_an(trophic_part)} #{trophic_part}."
        end

        @sentences << sentence if sentence
      end

      def lifespan_sentence
        trait = first_trait_for_pred_uri(Eol::Uris.lifespan)

        if trait 
          value = trait[:measurement]
          units_name = trait.dig(:units, :name)

          if value && units_name
            @sentences << "Individuals are known to live for #{value} #{units_name}."
          end
        end
      end

      def plant_description_sentence
        leaf_traits = Eol::Uris.flopos.collect { |uri| first_trait_for_pred_uri(uri) }.compact
        flower_trait = first_trait_for_pred_uri(Eol::Uris.flower_color)
        fruit_trait = first_trait_for_pred_uri(Eol::Uris.fruit_type)
        leaf_part = nil
        flower_part = nil
        fruit_part = nil

        if leaf_traits.any?
          leaf_parts = leaf_traits.collect { |trait| trait_sentence_part("%s", trait) }
          leaf_part = "#{leaf_parts.join(", ")} leaves"
        end

        if flower_trait
          flower_part = trait_sentence_part("%s flowers", flower_trait)
        end
          
        if fruit_trait
          fruit_part = trait_sentence_part("%s", fruit_trait)
        end

        parts = [leaf_part, flower_part, fruit_part].compact
        @sentences << "It has #{parts.to_sentence}." if parts.any? 
      end

      def flower_visitor_sentence
        traits = traits_for_pred_uri(Eol::Uris.flowers_visited_by).slice(0, FLOWER_VISITOR_LIMIT)

        if traits && traits.any?
          parts = traits.collect { |trait| trait_sentence_part("%s", trait) }
          @sentences << "Flowers are visited by #{parts.join(", ")}."
        end
      end

      # NOTE: Landmarks on staging = {"no_landmark"=>0, "minimal"=>1, "abbreviated"=>2, "extended"=>3, "full"=>4} For P.
      # lotor, there's no "full", the "extended" is Tetropoda, "abbreviated" is Carnivora, "minimal" is Mammalia. JR
      # believes this is usually a Class, but for different types of life, different ranks may make more sense.

      # A1: Use the landmark with value 1 that is the closest ancestor of the species. Use the English vernacular name, if
      # available, else use the canonical.
      def a1
        return @a1_link if @a1_link
        @a1 ||= @page.ancestors.reverse.find { |a| a && a.minimal? }
        return nil if @a1.nil?
        a1_name = @a1.page&.vernacular&.string&.singularize || @a1.vernacular&.singularize
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
        @g1 ||= values_to_sentence(['http://purl.obolibrary.org/obo/GAZ_00000071'])
      end

      def name_clause
        @name_clause ||=
          if @page.vernacular
            "#{@page.canonical} (#{@page.vernacular.string})"
          else
            @page.canonical
          end
      end

      # ...has a value with parent http://purl.obolibrary.org/obo/ENVO_00000447 for measurement type
      # http://eol.org/schema/terms/Habitat
      def is_it_marine?
        if @page.has_checked_marine?
          @page.is_marine?
        else
          env_terms = gather_terms([Eol::Uris.habitat_includes])
          marine =
            has_data_for_pred_terms(
              env_terms,
              values: [Eol::Uris.marine]
            ) &&
            !has_data_for_pred_terms(
              env_terms,
              values: [Eol::Uris.terrestrial]
            )

          @page.update_attribute(:has_checked_marine, true)
          # NOTE: this DOES NOT WORK without the true / false thing. :|
          @page.update_attribute(:is_marine, marine ? true : false)
          marine
        end
      end

      def has_data(options)
        has_data_for_pred_terms(gather_terms(options[:predicates]), options)
      end

      def has_data_for_pred_terms(pred_terms, options)
        recs = []
        pred_terms.each do |term|
          next if @page.grouped_data[term].nil?
          next if @page.grouped_data[term].empty?
          recs += @page.grouped_data[term]
        end
        recs.compact!
        return nil if recs.empty?
        values = gather_terms(options[:values])
        return nil if values.empty?
        return true if recs.any? { |r| r[:object_term] && values.include?(r[:object_term][:uri]) }
        return false
      end

      def traits_for_pred_uri(pred_uri)
        traits = []
        terms = gather_terms(pred_uri)
        
        terms.each do |term|
          traits_for_term = @page.grouped_data[term]
          traits.concat(traits_for_term) if traits_for_term
        end

        traits
      end
                        
      def first_trait_for_pred_uri(pred_uri)
        terms = gather_terms(pred_uri)
        
        terms.each do |term|
          recs = @page.grouped_data[term]

          if recs && recs.any?
            return recs.first
          end
        end

        nil
      end

      def first_trait_for_obj_uris(*obj_uris)
        obj_uris.each do |uri|
          recs = @page.grouped_data_by_obj_uri[uri]
          return recs.first if recs
        end

        return nil
      end

      def gather_terms(uris)
        terms = []
        Array(uris).each { |uri| terms << uri ; terms += TraitBank.descendants_of_term(uri).map { |t| t['uri'] } }
        terms.compact
      end

      # has value http://eol.org/schema/terms/extinct for measurement type http://eol.org/schema/terms/ExtinctionStatus
      def is_it_extinct?
        if @page.has_checked_extinct?
          @page.is_extinct?
        else
          # NOTE: this relies on #displayed_extinction_data ONLY returning an "extinct" record. ...which, as of this writing,
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
          next if @page.grouped_data[term].nil?
          @page.grouped_data[term].each do |trait|
            if trait.key?(:object_term)
              obj_term = trait[:object_term]
              values << term_tag(obj_term[:name], term, obj_term[:uri])
            else
              values << trait[:literal]
            end
          end
        end
        values.any? ? values.uniq.to_sentence : nil
      end

      # TODO: it would be nice to make these into a module included by the Page class.
      def is_species?
        is_rank?('r_species')
      end

      def is_family?
        is_rank?('r_family')
      end

      def is_genus?
        is_rank?('r_genus')
      end

      # NOTE: the secondary clause here is quite... expensive. I recommend we remove it, or if we keep it, preload ranks.
      # NOTE: Because species is a reasonable default for many resources, I would caution against *trusting* a rank of
      # species for *any* old resource. You have been warned.
      def is_rank?(rank)
        if @page.rank
          @page.rank.treat_as == rank
        # else
        #   @page.nodes.any? { |n| n.rank&.treat_as == rank }
        end
      end

      def rank_or_clade(node)
        node.rank.try(:name) || "clade"
      end

      # Note: this does not always work (e.g.: "an unicorn")
      def a_or_an(word)
        %w(a e i o u).include?(word[0].downcase) ? "an" : "a"
      end

      def conservation_sentence
        status_recs = @page.conservation_statuses
        result = []

        result << handle_iucn(status_recs[:iucn]) if status_recs.include?(:iucn) && IUCN_URIS.include?(status_recs[:iucn][:uri])
        result << handle_usfw(status_recs[:usfw]) if status_recs.include?(:usfw)
        result << handle_cites(status_recs[:cites]) if status_recs.include?(:cites )
        if result.any?
          sentence = "It is listed #{result.to_sentence(words_connector: ", ", last_word_connector: " and ")}."
          @sentences << sentence
        end
          
      end

      def handle_iucn(rec)
        term_sentence_part(
          "as %s by IUCN",
          rec[:name],
          Eol::Uris::Conservation.status,
          rec[:uri],
          rec[:source]
        )
      end

      def handle_cites(rec)
        term_sentence_part(
          "in %s",
          rec[:name],
          Eol::Uris::Conservation.status,
          rec[:uri],
          rec[:source]
        )
      end

      def handle_usfw(rec)
        term_sentence_part(
          "as %s by the US Fish and Wildlife Service",
          rec[:name],
          Eol::Uris::Conservation.status,
          rec[:uri],
          rec[:source]
        )
      end

      def term_toggle_id(term_name)
        "brief-summary-#{term_name.gsub(/\s/, "-")}"
      end

      def term_tag(label, pred_uri, obj_uri, trait_source = nil)
        toggle_id = term_toggle_id(label)
        @terms << ResultTerm.new(
          pred_uri,
          TraitBank.term_as_hash(obj_uri),
          trait_source,
          "##{toggle_id}"
        )
        view.content_tag(:span, label, class: ["a", "term-info-a"], id: toggle_id)
      end

      def term_sentence(format_str, label, pred_uri, obj_uri)
        @sentences << term_sentence_part(
          format_str, 
          label, 
          pred_uri, 
          obj_uri
        )
      end

      def term_sentence_part(format_str, label, pred_uri, obj_uri, source = nil)
        sprintf(
          format_str,
          term_tag(label, pred_uri, obj_uri, source)
        )
      end

      def trait_sentence_part(format_str, trait)
        term_sentence_part(
          format_str, 
          trait[:object_term][:name], 
          trait[:predicate][:uri], 
          trait[:object_term][:uri]
        )
      end

      def trait_sentence(format_str, trait)
        @sentences << trait_sentence_part(format_str, trait)
      end
  end
end
