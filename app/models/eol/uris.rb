module Eol
  module Uris
    class << self
      INVERSES = self.build_inverses

      def environment
        'http://eol.org/schema/terms/Habitat'
      end

      def marine
        "http://purl.obolibrary.org/obo/ENVO_00000447"
      end

      def terrestrial
        "http://purl.obolibrary.org/obo/ENVO_00000446"
      end

      def extinction
        'http://eol.org/schema/terms/ExtinctionStatus'
      end

      def extinct
        'http://eol.org/schema/terms/extinct'
      end

      def trophic_level
        'http://eol.org/schema/terms/TrophicGuild'
      end

      def geographics
        [
         'http://rs.tdwg.org/dwc/terms/continent',
         'http://rs.tdwg.org/dwc/terms/waterBody',
         'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Distribution'
        ]
      end

      def growth_habit
        'http://eol.org/schema/terms/growthHabit'
      end

      def tree
        "http://purl.obolibrary.org/obo/FLOPO_0900033"
      end

      def shrub
        "http://purl.obolibrary.org/obo/FLOPO_0900034"
      end

      def eaten_by
        "http://purl.obolibrary.org/obo/RO_0002471"
      end

      def eats
        "http://purl.obolibrary.org/obo/RO_0002470"
      end

      def ectoparasite_of
        "http://purl.obolibrary.org/obo/RO_0002632"
      end

      def has_ectoparasite
        "http://purl.obolibrary.org/obo/RO_0002633"
      end

      private
      def build_inverses
        one_dir_inverses = {
          self.eats => self.is_eaten_by,
          self.ectoparasite_of => self.has_ectoparasite
        }
        one_dir_inverses.merge(one_dir_inverses.invert)
      end
    end

    def marine
      'http://purl.obolibrary.org/obo/ENVO_00000447'
    end

    module Iucn
      class << self
        def status
          "http://rs.tdwg.org/ontology/voc/SPMInfoItems#ConservationStatus"
        end

        @@codes = {
          ex: "http://eol.org/schema/terms/extinct",
          ew: "http://eol.org/schema/terms/exinctInTheWild",
          cr: "http://eol.org/schema/terms/criticallyEndangered",
          en: "http://eol.org/schema/terms/endangered",
          vu: "http://eol.org/schema/terms/vulnerable",
          nt: "http://eol.org/schema/terms/nearThreatened",
          lc: "http://eol.org/schema/terms/leastConcern",
          dd: "http://eol.org/schema/terms/dataDeficient",
          ne: "http://eol.org/schema/terms/notEvaluated"
        }

        def uri_to_code(uri)
          @@codes.each { |code, c_uri| return code if c_uri == uri }
          nil
        end

        def code_to_uri(code)
          @@codes[code]
        end

        @@codes.each do |code, uri|
          define_method(code) do
            uri
          end
        end
      end
    end
  end
end
