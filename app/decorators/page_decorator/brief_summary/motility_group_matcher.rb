class PageDecorator
  class BriefSummary
    class MotilityGroupMatcher
      MATCHER = PageDecorator::BriefSummary::ObjUriGroupMatcher.new({
        type: :a,
        uris: [
          "http://eol.org/schema/terms/facultativelyMobile",
          "http://purl.obolibrary.org/obo/NBO_0000366",
          "http://www.wikidata.org/entity/Q1759860",
          "http://eol.org/schema/terms/fastMoving",
          "http://eol.org/schema/terms/passivelyMobile",
          "http://eol.org/schema/terms/slowMoving",
          "http://eol.org/schema/terms/cursorial"
        ]
      }, {
        type: :b,
        uris: [
          "http://polytraits.lifewatchgreece.eu/terms/MOB_BUR",
          "http://polytraits.lifewatchgreece.eu/terms/MOB_CRAWL",
          "http://polytraits.lifewatchgreece.eu/terms/MOB_SWIM"
        ]
      }, {
        type: :c,
        uris: [
          "http://purl.obolibrary.org/obo/NBO_0000367",
          "http://eol.org/schema/terms/ciliary_gliding",
          "http://purl.obolibrary.org/obo/NBO_0000364",
          "http://purl.obolibrary.org/obo/NBO_0000370",
          "http://purl.obolibrary.org/obo/NBO_0000369",
          "http://purl.obolibrary.org/obo/NBO_0000055"
        ]
      })

      class << self
        def match_all(traits)
          MATCHER.match_all(traits)
        end
      end
    end
  end
end




