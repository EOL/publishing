# Contains language/locale-agnostic methods used for constructing summaries
# TODO: Rename! e.g. LanguagesShared or something
class BriefSummary
  module Shared
    class BadTraitError < TypeError; end

    Result = Struct.new(:sentence, :terms)

    # NOTE: Landmarks on staging = {"no_landmark"=>0, "minimal"=>1, "abbreviated"=>2, "extended_landmark"=>3, "full"=>4} For P.
    # lotor, there's no "full", the "extended_landmark" is Tetropoda, "abbreviated" is Carnivora, "minimal" is Mammalia. JR
    # believes this is usually a Class, but for different types of life, different ranks may make more sense.

    def add_sentence(options = {})
      sentence = nil

      begin
        sentence = yield
      rescue BadTraitError => e
        Rails.logger.warn(e.message)
      end

      if sentence.present?
        @sentences << sentence
      end
    end

    def reproduction_matches
      @reproduction_matches ||= ReproductionGroupMatcher.match_all(@page.traits_for_predicate(TermNode.find_by_alias('reproduction')))
    end
    
    # ...has a value with parent http://purl.obolibrary.org/obo/ENVO_00000447 for measurement type
    # http://eol.org/schema/terms/Habitat
    def is_it_marine?
      habitat_term = TermNode.find_by_alias('habitat')
      @page.has_data_for_predicate(
        habitat_term,
        with_object_term: TermNode.find_by_alias('marine')
      ) &&
      !@page.has_data_for_predicate(
        habitat_term,
        with_object_term: TermNode.find_by_alias('terrestrial')
      )
    end

    def freshwater_trait
      @freshwater_trait ||= @page.first_trait_for_object_terms([TermNode.find_by_alias('freshwater')])
    end

    def is_species?
      is_rank?('r_species')
    end

    def is_family?
      is_rank?('r_family')
    end

    def is_genus?
      is_rank?('r_genus')
    end

    def below_family?
    end

    def genus_or_below?
      @page.rank&.treat_as.present? && Rank.treat_as[@page.rank.treat_as] >= Rank.treat_as[:r_genus]
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

    def term_tag(label, predicate, term, trait_source = nil)
      toggle_id = register_term(predicate, term, trait_source)
      view.content_tag(:span, label, class: ["a", "term-info-a"], id: toggle_id)
    end

    def i18n_w_term(key, predicate, term, trait_source = nil)
      toggle_id = register_term(predicate, term, trait_source)
      I18n.t("brief_summary.#{key}", class_str: 'a term-info-a', id: toggle_id)
    end
    
    def register_term(predicate, term, trait_source)
      toggle_id = term_toggle_id

      @terms << ResultTerm.new(
        predicate,
        term,
        trait_source,
        "##{toggle_id}"
      )

      toggle_id
    end

    # Term can be a predicate or an object term. If predicate is nil, term is treated in the view
    # as a predicate; otherwise, it's treated as an object term.
    def term_sentence_part(format_str, label, predicate, term, source = nil)
      sprintf(
        format_str,
        term_tag(label, predicate, term, source)
      )
    end

    def trait_sentence_part(format_str, trait, options = {})
      return '' if trait.nil?

      if trait.object_page
        association_sentence_part(format_str, trait.object_page)
      elsif trait.predicate && trait.object_term
        name = trait.object_term.name
        name = name.pluralize if options[:pluralize]
        predicate = trait.predicate
        obj = trait.object_term

        term_sentence_part(
          format_str,
          name,
          predicate,
          obj
        )
      elsif trait.literal
        sprintf(format_str, trait.literal)
      else
        raise BadTraitError.new("Undisplayable trait: #{trait.id}")
      end
    end

    def association_sentence_part(format_str, object_page)
      object_page_part = if object_page.nil?
                           Rails.logger.warn("Missing associated page for auto-generated text")
                           "(page not found)"
                         else
                           view.link_to(object_page.short_name(Locale.english).html_safe, object_page)
                         end
      sprintf(format_str, object_page_part)
    end


    def add_family_sentence
      add_sentence do
        "#{full_name_clause} is a family of #{a1}."
      end
    end

    def add_extinction_sentence
      if extinct?
        add_sentence do
          key = "extinction.#{@page.rank.treat_as}"
          i18n_w_term(key, TermNode.find_by_alias('extinction_status'), extinct_trait.object_term)
        end

        true
      else
        false
      end
    end

    def result
      add_sentences
      Result.new(@sentences.join(' '), @terms)
    end

    def sentences
      @sentences
    end
  end
end
