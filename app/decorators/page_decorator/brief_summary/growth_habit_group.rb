require "set"

# Different groups of 'growth habit' trait values are treated differently in BriefSummary. 
# This class provides functionality for classifying a growth habit trait by matching its object term
# against the uris in these groups.
class PageDecorator
  class BriefSummary
    class GrowthHabitGroup
      attr_accessor :type

      def initialize(type, uris)
        @type = type
        @uris = Set.new(uris)
      end

      def include?(uri)
        @uris.include? uri
      end

      class << self 
        Groups = [
          GrowthHabitGroup.new(:x_species, [
            "http://eol.org/schema/terms/lichenous",
            "http://eol.org/schema/terms/woodyPlant",
            "https://www.wikidata.org/entity/Q757163",
            "http://eol.org/schema/terms/semi-woody",
            "https://www.wikidata.org/entity/Q190903"
          ]),
          GrowthHabitGroup.new(:and_a_x, [
            "http://eol.org/schema/terms/obligateClimber",
            "http://eol.org/schema/terms/facultativeClimber",
            "http://purl.obolibrary.org/obo/FLOPO_0900035",
            "https://www.wikidata.org/entity/Q14079",
            "http://www.wikidata.org/entity/Q189939",
          ]),
          GrowthHabitGroup.new(:x_growth_habit, [
            "http://eol.org/schema/terms/crustose",
            "http://eol.org/schema/terms/squamulose",
            "http://eol.org/schema/terms/fructose",
            "http://eol.org/schema/terms/self-supportingGrowthForm",
            "http://eol.org/schema/terms/foliose",
            "http://purl.obolibrary.org/obo/PATO_0002389",
          ]),
          GrowthHabitGroup.new(:species_of_x, [
            Eol::Uris.tree,
            Eol::Uris.shrub
          ]),
          GrowthHabitGroup.new(:species_of_lifecycle_x, [
            "http://purl.obolibrary.org/obo/FLOPO_0900036",
            "http://purl.obolibrary.org/obo/FLOPO_0022142"
          ])
        ]

        def match(trait)
          return nil if !trait[:object_term]
          uri = trait[:object_term][:uri]

          found_group = nil
          Groups.each do |group|
            if group.include? uri
              found_group = group
              break
            end
          end

          if found_group
            Match.new(found_group, trait)
          else
            nil
          end
        end 

        def match_all(traits)
          matches = []

          traits.each do |trait|
            match = self.match(trait)
            matches << match if match
          end

          Matches.new(matches)
        end
      end

      class Match
        attr_accessor :type
        attr_accessor :trait

        def initialize(group, trait)
          @type = group.type
          @trait = trait
        end
      end

      class Matches
        def initialize(matches)
          matches_by_uri = matches.group_by do |match|
            match.trait[:object_term][:uri]
          end

          matches_by_type = matches.group_by do |match|
            match.type
          end

          @matches =  if matches_by_uri.has_key?(Eol::Uris.tree)
                        [matches_by_uri[Eol::Uris.tree].first] 
                      elsif matches_by_uri.has_key?(Eol::Uris.shrub)
                        [matches_by_uri[Eol::Uris.shrub].first]
                      elsif matches_by_type.has_key?(:x_species) &&
                        (matches_by_type.has_key?(:and_a_x) || matches_by_type.has_key?(:x_growth_habit))

                        x_species_matches = [matches_by_type[:x_species].first]
                        if matches_by_type.has_key? :and_a_x
                          x_species_matches << matches_by_type[:and_a_x].first
                        else
                          x_species_matches << matches_by_type[:x_growth_habit].first
                        end

                        x_species_matches
                      elsif matches.any?
                        [matches.first]
                      else
                        []
                      end  
        end

        def has_type?(type)
          @matches.any? { |match| match.type == type }
        end

        def by_type(type)
          @matches.find { |match| match.type == type }
        end
      end
    end
  end
end

