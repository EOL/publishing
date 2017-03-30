module Eol
  module Uris
    class << self
      def environment
        "http://eol.org/schema/terms/Habitat"
      end

      def extinction
        "http://eol.org/schema/terms/ExtinctionStatus"
      end

      def extinct
        "http://eol.org/schema/terms/extinct"
      end

      def geographics
        [
         "http://rs.tdwg.org/dwc/terms/continent",
         "http://rs.tdwg.org/dwc/terms/waterBody",
         "http://rs.tdwg.org/ontology/voc/SPMInfoItems#Distribution"
        ]
      end

      def marine
        "http://purl.obolibrary.org/obo/ENVO_00000569"
      end

      def redlist_status
        "http://eol.org/schema/terms/RedListCategory"
      end

    end

    module Iucn
      class << self
        def status
          "http://rs.tdwg.org/ontology/voc/SPMInfoItems#ConservationStatus"
        end

        def ex
          "http://eol.org/schema/terms/extinct"
        end

        def ew
          "http://eol.org/schema/terms/exinctInTheWild"
        end

        def cr
          "http://eol.org/schema/terms/criticallyEndangered"
        end

        def en
          "http://eol.org/schema/terms/endangered"
        end

        def vu
          "http://eol.org/schema/terms/vulnerable"
        end

        def nt
          "http://eol.org/schema/terms/nearThreatened"
        end

        def lc
          "http://eol.org/schema/terms/leastConcern"
        end

        def dd
          "http://eol.org/schema/terms/dataDeficient"
        end

        def ne
          "http://eol.org/schema/terms/notEvaluated"
        end
      end
    end
  end
end
