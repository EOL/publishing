require "set"

class PageDecorator
  class BriefSummary
    class GrowthHabitGroup
      attr_accessor :type

      def initialize(type, uris)
        @type = type
        @uris = Set.new(uris)
      end

      class << self 
        Groups = [
          GrowthHabitGroup.new(:x_species, [
            "http://eol.org/schema/terms/lichenous",
            "http://eol.org/schema/terms/woodyPlant",
            "https://www.wikidata.org/entity/Q757163",
            "http://eol.org/schema/terms/semi-woody",
            "https://www.wikidata.org/entity/Q190903",
            "http://purl.obolibrary.org/obo/FLOPO_0900036",
            "http://purl.obolibrary.org/obo/FLOPO_0022142",
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
            "http://purl.obolibrary.org/obo/FLOPO_0900034",
            "http://purl.obolibrary.org/obo/FLOPO_0900033",
          ])
        ]

        def match(obj_term)
          found_group = nil
          Groups.each do |group|
            if group.include? uri
              found_group = group
              break
            end
          end

          if found_group
            MatchResult.new(found_group, obj_term)
          else
            nil
          end
        end 
      end

      class MatchResult
        attr_accessor :type
        attr_accessor :obj_term

        def initialize(group, obj_term)
          @type = group.type
          @obj_term = obj_term
        end
      end
    end
  end
end

