require "set"

# Different groups of 'growth habit' trait values are treated differently in BriefSummary. 
# This class provides functionality for classifying a growth habit trait by matching its object term
# against the uris in these groups.
class PageDecorator
  class BriefSummary
    class GrowthHabitGroup
      class << self 
        MATCHER = PageDecorator::BriefSummary::ObjUriGroupMatcher.new({
          type: :x_species,
          uris: [
            "http://eol.org/schema/terms/lichenous",
            "http://eol.org/schema/terms/woodyPlant",
            "https://www.wikidata.org/entity/Q757163",
            "http://eol.org/schema/terms/semi-woody",
            "https://www.wikidata.org/entity/Q190903"
          ]
        }, {
          type: :and_a_x, 
          uris: [
            "http://eol.org/schema/terms/obligateClimber",
            "http://eol.org/schema/terms/facultativeClimber",
            "http://purl.obolibrary.org/obo/FLOPO_0900035",
            "https://www.wikidata.org/entity/Q14079",
            "http://www.wikidata.org/entity/Q189939"
          ]
        }, {
          type: :x_growth_habit,
          uris: [
            "http://eol.org/schema/terms/crustose",
            "http://eol.org/schema/terms/squamulose",
            "http://eol.org/schema/terms/fructose",
            "http://eol.org/schema/terms/self-supportingGrowthForm",
            "http://eol.org/schema/terms/foliose",
            "http://purl.obolibrary.org/obo/PATO_0002389",
          ]
        }, {
          type: :species_of_x, 
          uris: [
            Eol::Uris.tree,
            Eol::Uris.shrub
          ]
        }, {
          type: :species_of_lifecycle_x,
          uris: [
            "http://purl.obolibrary.org/obo/FLOPO_0900036",
            "http://purl.obolibrary.org/obo/FLOPO_0022142"
          ]
        })

        def match_all(traits)
          matches = MATCHER.match_all(traits)

          filtered_matches = if matches.has_uri?(Eol::Uris.tree)
            [matches.by_uri(Eol::Uris.tree).first] 
          elsif matches.has_uri?(Eol::Uris.shrub)
            [matches_by_uri(Eol::Uris.shrub).first]
          elsif matches.has_type?(:x_species) &&
            (matches.has_type?(:and_a_x) || matches.has_type?(:x_growth_habit))

            x_species_matches = [matches.by_type(:x_species).first]
            if matches.has_type?(:and_a_x)
              x_species_matches << matches.by_type(:and_a_x).first
            else
              x_species_matches << matches.by_type(:x_growth_habit).first
            end

            x_species_matches
          elsif matches.any?
            [matches.first]
          else
            []
          end

          ObjUriGroupMatcher::Matches.new(filtered_matches)
        end
      end
    end
  end
end

