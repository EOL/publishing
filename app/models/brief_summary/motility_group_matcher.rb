class BriefSummary
  class MotilityGroupMatcher
    MATCHER = BriefSummary::ObjUriGroupMatcher.new({
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
        "http://purl.obolibrary.org/obo/NBO_0000055",
        "http://purl.obolibrary.org/obo/GO_0036268",
        "https://eol.org/schema/terms/anal_dorsal_fins",
        "https://eol.org/schema/terms/anal_fin",
        "https://eol.org/schema/terms/anguilliform",
        "https://eol.org/schema/terms/body_caudal_fin",
        "https://eol.org/schema/terms/carangiform",
        "https://eol.org/schema/terms/carcharhiniform",
        "https://eol.org/schema/terms/dorsal_fin",
        "https://eol.org/schema/terms/dorsoventral_undulatory",
        "https://eol.org/schema/terms/drag_based_swimming",
        "https://eol.org/schema/terms/lift_based_swimming",
        "https://eol.org/schema/terms/median_paired_fin",
        "https://eol.org/schema/terms/ostraciiform",
        "https://eol.org/schema/terms/pectoral_fins",
        "https://eol.org/schema/terms/pectoral_oscillation",
        "https://eol.org/schema/terms/subcarangiform",
        "https://eol.org/schema/terms/thunniform",
      ]
    })

    class << self
      def match_all(traits)
        MATCHER.match_all(traits)
      end
    end
  end
end

