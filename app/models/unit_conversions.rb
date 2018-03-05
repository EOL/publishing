class UnitConversions
  @functions = [
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000021" ],        # grams
      starting_units_label: "g",
      ending_unit:      "grams",
      function:         lambda { |v| v } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000022" ],        # mg
      starting_units_label: "mg",
      ending_unit:      "grams",
      function:         lambda { |v| v * 0.001 } },
    { starting_units:   [ "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C64555" ], # decigram
      starting_units_label: "dg",
      ending_unit:      "grams",
      function:         lambda { |v| v * 0.1 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000025" ],        # picogram
      starting_units_label: "pg"
      ending_unit:      "grams",
      function:         lambda { |v| v * (10 ** -12) } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#US_pound" ], # pound
      starting_units_label: "lb",
      ending_unit:      "grams",
      function:         lambda { |v| v * 453.592 } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#US_ounce" ], # ounce
      starting_units_label: "oz",
      ending_unit:      "grams",
      function:         lambda { |v| v * 28.3495 } },
    { starting_units:   [ "http://eol.org/schema/terms/log10gram" ],            # Log base 10 grams
      starting_units_label: "log_10 g",
      ending_unit:      "grams",
      function:         lambda { |v| 10.0 ** v } },
    # TODO: we need centimeters (unconverted)
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000008" ],        # meter
      starting_units_label: "m"
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 100 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000016", "http://adw.org/mm" ], # mm
      starting_units_label: "mm"
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 0.1 } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#foot" ], # foot
      starting_units_label: "ft",
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 30.48 } },
    { starting_units:   [ "http://mimi.case.edu/ontologies/2009/1/UnitsOntology#inch" ], # inch
      starting_units_label: "in",
      ending_unit:      "centimeters",
      function:         lambda { |v| v * 2.54 } },
    # TODO: we need celsius (unconverted)
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000012", "http://anage.org/k" ], # Kelvin
      starting_units_label: "k",
      ending_unit:      "celsius",
      function:         lambda { |v| v - 273.15 } },
    { starting_units:   [ "http://eol.org/schema/terms/onetenthdegreescelsius" ], # 1/10th C
      starting_units_label: "1/10th c",
      ending_unit:      "celsius",
      function:         lambda { |v| v / 10.0 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000195" ],        # farenheight
      starting_units_label: "f",
      ending_unit:      "celsius",
      function:         lambda { |v| (((v - 32) * 5) / 9.0) } },
    # TODO: we need years (unconverted)
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000033", "http://anage.org/days", "http://eol.org/schema/terms/day" ], # days
      starting_units_label: "days",
      ending_unit:      "years",
      function:         lambda { |v| v / 365.2425 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000035" ],        # months
      starting_units_label: "months",
      ending_unit:      "years",
      function:         lambda { |v| v / 12.0 } },
    # TODO: we need suqare meters (unconverted)
    { starting_units:   [ "http://eol.org/schema/terms/squareMicrometer" ],     # square micrometer
      starting_units_label: "μm^2",
      ending_unit:      "m^2",
      function:         lambda { |v| v * 1e-12 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000082" ],        # square millimeter
      starting_units_label: "mm^2",
      ending_unit:      "m^2",
      function:         lambda { |v| v * 1e-06 } },
    { starting_units:   [ "http://purl.obolibrary.org/obo/UO_0000081" ],        # square centimeter
      starting_units_label: "cm^2",
      ending_unit:      "m^2",
      function:         lambda { |v| v * 0.0001 } },
    { starting_units:   [ "http://eol.org/schema/terms/squarekilometer" ],      # square kilometer
      starting_units_label: "km^2",
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
      result = convert_or_nil(val, units_uri)
      result || [val, units_uri] 
    end

    def convert_or_nil(val, units_uri)
      return([val, units_uri]) unless can_convert?(units_uri)
      fn = @functions.find { |f| f[:starting_units].include?(units_uri) }
      [fn[:function].call(val), fn[:ending_unit]]
    end

    def starting_units_for_ending_unit(ending_unit)
      @starting_units_for_ending_units ||= @functions.map do |fn|
        [fn[:ending_unit], { :label => fn[:starting_units_label], :starting_units => fn[:starting_units] }]
      end.to_h

      @starting_units_for_ending_units[ending_unit]
    end
  end
end
