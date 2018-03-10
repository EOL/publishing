# NOTE: this is copied VERBATIM from the harvesting code base. Chage one, change both!
# TODO: Stop that! :D Make it a gem or something.
class UnitConversions
  @functions = [
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000022'], # mg
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000021', # g
      function:         ->(v) { v * 0.001 } },
    { starting_units:   ['http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C64555'], # decigram
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000021', # g
      function:         ->(v) { v * 0.1 } },
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000025'], # picogram
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000021', # g
      function:         ->(v) { v * (10**-12) } },
    { starting_units:   ['http://mimi.case.edu/ontologies/2009/1/UnitsOntology#US_pound'], # pound
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000021', # g
      function:         ->(v) { v * 453.592 } },
    { starting_units:   ['http://mimi.case.edu/ontologies/2009/1/UnitsOntology#US_ounce'], # ounce
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000021', # g
      function:         ->(v) { v * 28.3495 } },
    { starting_units:   ['http://eol.org/schema/terms/log10gram'], # Log base 10 grams
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000021', # g
      function:         ->(v) { 10.0**v } },
    # TODO: we need centimeters (unconverted)
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000008'], # meter
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000015', # cm
      function:         ->(v) { v * 100 } },
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000016', 'http://adw.org/mm'], # mm
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000015', # cm
      function:         ->(v) { v * 0.1 } },
    { starting_units:   ['http://mimi.case.edu/ontologies/2009/1/UnitsOntology#foot'], # foot
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000015', # cm
      function:         ->(v) { v * 30.48 } },
    { starting_units:   ['http://mimi.case.edu/ontologies/2009/1/UnitsOntology#inch'], # inch
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000015', # cm
      function:         ->(v) { v * 2.54 } },
    # TODO: we need celsius (unconverted)
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000012', 'http://anage.org/k'], # Kelvin
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000027', # degrees Celsius
      function:         ->(v) { v - 273.15 } },
    { starting_units:   ['http://eol.org/schema/terms/onetenthdegreescelsius'], # 1/10th C
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000027', # degrees Celsius
      function:         ->(v) { v / 10.0 } },
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000195'], # farenheight
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000027', # degrees Celsius
      function:         ->(v) { (((v - 32) * 5) / 9.0) } },
    # TODO: we need years (unconverted)
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000033', 'http://anage.org/days',
                         'http://eol.org/schema/terms/day'], # days
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000036', # years
      function:         ->(v) { v / 365.2425 } },
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000035'], # months
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000036', # years
      function:         ->(v) { v / 12.0 } },
    # TODO: we need suqare meters (unconverted)
    { starting_units:   ['http://eol.org/schema/terms/squareMicrometer'], # square micrometer
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000080', # square meters
      function:         ->(v) { v * 1e-12 } },
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000082'], # square millimeter
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000080', # square meters
      function:         ->(v) { v * 1e-06 } },
    { starting_units:   ['http://purl.obolibrary.org/obo/UO_0000081'], # square centimeter
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000080', # square meters
      function:         ->(v) { v * 0.0001 } },
    { starting_units:   ['http://eol.org/schema/terms/squarekilometer'], # square kilometer
      ending_unit:      'http://purl.obolibrary.org/obo/UO_0000080', # square meters
      function:         ->(v) { v * 1_000_000 } }
  ]

  class << self
    attr_reader :functions

    def all_starting_units
      @all_starting_units ||= @functions.flat_map { |fn| fn[:starting_units] }
    end

    def can_convert?(units_uri)
      all_starting_units.include?(units_uri)
    end

    def starting_units(uri)
      @ending_unit_to_starting_units ||= @functions.map { |f| [f[:ending_unit], f[:starting_units]] }.to_h
      @ending_unit_to_starting_units[uri]
    end

    def convert(val, units_uri)
      return([val, units_uri]) unless can_convert?(units_uri)
      fn = @functions.find { |f| f[:starting_units].include?(units_uri) }
      [fn[:function].call(val), fn[:ending_unit]]
    end
  end
end
