module Eol
  module Uris
    class << self
      def habitat_includes
        'http://eol.org/schema/terms/Habitat'
      end

      def habitat_is
        "http://rs.tdwg.org/dwc/terms/habitat"
      end

      def habitat_breadth
        "http://eol.org/schema/terms/HabitatBreadth"
      end

      def habitats
        [
          habitat_includes,
          habitat_breadth,
          habitat_is
        ]
      end

      # uris for wordcloud records -- not necessarily the uris that allow the wordcloud to be shown
      def habitats_for_wordcloud
        [
          habitat_includes,
          habitat_is
        ]
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

      def eats
        "http://purl.obolibrary.org/obo/RO_0002470" 
      end

      def is_eaten_by
        "http://purl.obolibrary.org/obo/RO_0002471"
      end

      def ectoparasite_of
        "http://purl.obolibrary.org/obo/RO_0002632"
      end

      def has_ectoparasite
        "http://purl.obolibrary.org/obo/RO_0002633"
      end

      def has_endoparasite
        "http://purl.obolibrary.org/obo/RO_0002635"
      end
      
      def endoparasite_of
        "http://purl.obolibrary.org/obo/RO_0002634"
      end

      def epiphyte_of
        "http://purl.obolibrary.org/obo/RO_0008501"
      end

      def has_epiphyte
        "http://purl.obolibrary.org/obo/RO_0008502"
      end

      def has_hyperparasite
        "http://purl.obolibrary.org/obo/RO_0002554"
      end

      def hyperparasite_of
        "http://purl.obolibrary.org/obo/RO_0002553"
      end
      
      def host_of
        "http://purl.obolibrary.org/obo/RO_0002453"
      end

      def has_host
        "http://purl.obolibrary.org/obo/RO_0002454"
      end

      def is_killed_by
        "http://purl.obolibrary.org/obo/RO_0002627"
      end

      def kills
        "http://purl.obolibrary.org/obo/RO_0002626"
      end

      def lays_eggs_on
        "http://purl.obolibrary.org/obo/RO_0008507"
      end

      def has_eggs_laid_on_by
        "http://purl.obolibrary.org/obo/RO_0008508"
      end

      def parasite_of
        "http://purl.obolibrary.org/obo/RO_0002444"
      end

      def has_parasite 
        "http://purl.obolibrary.org/obo/RO_0002445"
      end

      def parasitoid_of
        "http://purl.obolibrary.org/obo/RO_0002208"
      end

      def has_parasitoid
        "http://purl.obolibrary.org/obo/RO_0002209"
      end

      def pathogen_of
        "http://purl.obolibrary.org/obo/RO_0002556"
      end

      def has_pathogen
        "http://purl.obolibrary.org/obo/RO_0002557"
      end

      def pollinated_by
        "http://purl.obolibrary.org/obo/RO_0002456"
      end

      def pollinates
        "http://purl.obolibrary.org/obo/RO_0002455"
      end

      def preyed_upon_by
        "http://purl.obolibrary.org/obo/RO_0002458"
      end

      def preys_on
        "http://purl.obolibrary.org/obo/RO_0002439"
      end

      def has_vector
        "http://purl.obolibrary.org/obo/RO_0002460"
      end

      def vector_of
        "http://purl.obolibrary.org/obo/RO_0002459"
      end

      def visited_by
        "http://purl.obolibrary.org/obo/RO_0002619"
      end

      def visits
        "http://purl.obolibrary.org/obo/RO_0002618"
      end

      def visits_flowers_of
        "http://purl.obolibrary.org/obo/RO_0002622"
      end

      def flowers_visited_by
        "http://purl.obolibrary.org/obo/RO_0002623"
      end

      def sex
        "http://rs.tdwg.org/dwc/terms/sex"
      end

      def lifestage
        "http://rs.tdwg.org/dwc/terms/lifeStage"
      end

      def statistical_method
        "http://eol.org/schema/terms/statisticalMethod"
      end

      def nocturnal
        "http://www.wikidata.org/entity/Q309179"
      end

      def diurnal
        "http://www.wikidata.org/entity/Q906470"
      end

      def crepuscular
        "http://purl.obolibrary.org/obo/ECOCORE_00000078"
      end

      def solitary
        "http://eol.org/schema/terms/solitary"
      end

      def lifespan
        "http://purl.obolibrary.org/obo/VT_0001661"
      end

      def flopos
        ["http://purl.obolibrary.org/obo/FLOPO_0007484", "http://purl.obolibrary.org/obo/FLOPO_0019932"]
      end

      def flower_color
        "http://purl.obolibrary.org/obo/TO_0000537"
      end

      def fruit_type
        "http://purl.obolibrary.org/obo/TO_0000850"
      end

      def fossil_first
        "http://eol.org/schema/terms/FossilFirst"
      end

      def inverse(uri)
        INVERSES[uri]
      end
    end

    def self.build_inverses
      one_dir_inverses = {
        self.eats => self.is_eaten_by,
        self.ectoparasite_of => self.has_ectoparasite,
        self.endoparasite_of => self.has_endoparasite,
        self.epiphyte_of => self.has_epiphyte,
        self.has_hyperparasite => self.hyperparasite_of,
        self.host_of => self.has_host,
        self.is_killed_by => self.kills,
        self.lays_eggs_on => self.has_eggs_laid_on_by,
        self.parasite_of => self.has_parasite,
        self.parasitoid_of => self.has_parasitoid,
        self.pathogen_of => self.has_pathogen,
        self.pollinated_by => self.pollinates,
        self.preyed_upon_by => self.preys_on,
        self.has_vector => self.vector_of,
        self.visited_by => self.visits,
        self.visits_flowers_of => self.flowers_visited_by
      }

      one_dir_inverses.merge(one_dir_inverses.invert)
    end
    INVERSES = self.build_inverses


    def marine
      'http://purl.obolibrary.org/obo/ENVO_00000447'
    end

    module Iucn
      CODES_TO_URIS = {
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

      class << self
        CODES_TO_URIS.each do |code, uri|
          define_method(code) do
            uri
          end
        end
      end
    end

    module Conservation
      class << self
        def status
          "http://rs.tdwg.org/ontology/voc/SPMInfoItems#ConservationStatus"
        end

        def iucn?(uri)
          IUCN_URIS.include? uri
        end

        def cites?(uri)
          CITES_URIS.include? uri
        end

        def usfw?(uri)
          USFW_URIS.include? uri
        end

        IUCN_URIS = Set[
          Iucn.ex,
          Iucn.ew,
          Iucn.cr,
          Iucn.en,
          Iucn.vu,
          Iucn.nt,
          Iucn.nt,
          Iucn.lc,
          Iucn.dd,
          Iucn.ne
        ]

        CITES_URIS = Set[
          "http://eol.org/schema/terms/CITES_I",
          "http://eol.org/schema/terms/CITES_II",
          "http://eol.org/schema/terms/CITES_III"
        ]

        # US Fish and Wildlife
        USFW_URIS = Set[
          "http://eol.org/schema/terms/federalEndangered",
          "http://eol.org/schema/terms/federalThreatened"
        ]
      end
    end
  end
end
