require 'set'

class BriefSummary
  module Sentences
    class Helper
      def initialize(tagger, view)
        @tagger = tagger
        @view = view
      end

      def pluralize(count, singular, plural = nil)
        @view.pluralize(count, singular, plural)
      end

      def add_term_to_fmt(fstr, label, predicate, term, source = nil)
        check_fstr(fstr)

        sprintf(
          fstr,
          @tagger.tag(label, predicate, term, source)
        )
      end

      def add_obj_page_to_fmt(fstr, obj_page)
        check_fstr(fstr)

        page_part = obj_page.nil? ?
          '(page not found)' :
          @view.link_to(obj_page.short_name.html_safe, obj_page)

        sprintf(fstr, page_part)
      end

      def add_trait_val_to_fmt(fstr, trait, options = {})
        raise TypeError, "trait can't be nil" if trait.nil?
        check_fstr(fstr)

        if trait.object_page.present?
          add_obj_page_to_fmt(fstr, trait.object_page)
        elsif trait.predicate.present? && trait.object_term.present?
          name = trait.object_term.i18n_name
          name = name.pluralize if options[:pluralize]

          add_term_to_fmt(
            fstr, 
            name,
            trait.predicate, 
            trait.object_term,
            nil
          )
        elsif trait.literal.present?
          sprintf(fstr, trait.literal)
        else
          raise BriefSummary::BadTraitError, "Invalid trait for add_trait_val_to_fmt: #{trait.id}"
        end
      end

      def trait_vals_to_sentence(traits, predicate = nil)
        seen_object_term_ids = Set.new

        traits.map do |trait|
          if trait.object_term
            next nil if seen_object_term_ids.include?(trait.object_term.eol_id)

            seen_object_term_ids.add(trait.object_term.eol_id)
            tag_predicate = predicate.nil? ? trait.predicate : predicate

            @tagger.tag(trait.object_term.i18n_name, tag_predicate, trait.object_term, nil)
          else
            trait.literal
          end
        end.compact.to_sentence
      end

      def toggle_id(predicate, term, source)
        @tagger.toggle_id(predicate, term, source)
      end

      def page_link(page)
        @view.link_to(page.vernacular_or_canonical, page)
      end
      
      private
      def check_fstr(fstr)
        raise TypeError, "fstr can't be blank" if fstr.blank?
      end
    end
  end
end

