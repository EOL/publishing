class UnitConversions
  @functions = [
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000021" ],        # grams
      ending_unit:      "grams",
      function:         lambda { |v| v } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000022" ],        # mg
      ending_unit:      "grams",
      function:         lambda { |v| v * 0.001 } },
    { starting_units:   [ "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C64555" ], # decigram
      ending_unit:      "grams",
      function:         lambda { |v| v * 0.1 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000025" ],        # picogram
      ending_unit:      "grams",
      function:         lambda { |v| v * (10 ** -12) } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#US_pound" ], # pound
      ending_unit:      "grams",
      function:         lambda { |v| v * 453.592 } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#US_ounce" ], # ounce
      ending_unit:      "grams",
      function:         lambda { |v| v * 28.3495 } },
    { starting_units:   [ "http://eol.org/schema/terms/log10gram" ],            # Log base 10 grams
      ending_unit:      "grams",
      function:         lambda { |v| 10.0 ** v } },
    # TODO: we need centimeters (unconverted)
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000008" ],        # meter
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 100 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000016", "http://adw.org/mm" ], # mm
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 0.1 } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#foot" ], # foot
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 30.48 } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#inch" ], # inch
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 2.54 } },
    # TODO: we need celsius (unconverted)
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000012", "http://anage.org/k" ], # Kelvin
      ending_unit:      "celsius",
      function:         lambda { |v| v - 273.15 } },
    { starting_units:   [ "http://eol.org/schema/terms/onetenthdegreescelsius" ], # 1/10th C
      ending_unit:      "celsius",
      function:         lambda { |v| v / 10.0 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000195" ],        # farenheight
      ending_unit:      "celsius",
      function:         lambda { |v| (((v - 32) * 5) / 9.0) } },
    # TODO: we need years (unconverted)
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000033", "http://anage.org/days", "http://eol.org/schema/terms/day" ], # days
      ending_unit:      "years",
      function:         lambda { |v| v / 365.2425 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000035" ],        # months
      ending_unit:      "years",
      function:         lambda { |v| v / 12.0 } },
    # TODO: we need suqare meters (unconverted)
    { starting_units:   [ "http://eol.org/schema/terms/squareMicrometer" ],     # square micrometer
      ending_unit:      "m^2",
      function:         lambda { |v| v * 1e-12 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000082" ],        # square millimeter
      ending_unit:      "m^2",
      function:         lambda { |v| v * 1e-06 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000081" ],        # square centimeter
      ending_unit:      "m^2",
      function:         lambda { |v| v * 0.0001 } },
    { starting_units:   [ "http://eol.org/schema/terms/squarekilometer" ],      # square kilometer
      ending_unit:      "m^2",
      function:         lambda { |v| v * 1_000_000 } }
  ]

  class << self
    attr_reader :functions

    def all_starting_units
      @all_starting_units ||= @functions.flat_map { |fn| fn[:starting_units] }
    end

    def can_convert?(units_uri)
      all_starting_units.include?(units_uri)
    end

    def convert(val, units_uri)
      return([val, units_uri]) unless can_convert?(units_uri)
      fn = @functions.find { |f| f[:starting_units].include?(units_uri) }
      [fn[:function].call(val), fn[:ending_unit]]
    end
  end
end
