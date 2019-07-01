module BreadcrumbType
  TYPES = {
    vernacular: 0,
    canonical: 1
  }
  TYPES_INVERTED = TYPES.invert

  class << self
    TYPES.each do |k, v|
      define_method(k) { v }
    end

    def default
      vernacular
    end

    def values
      TYPES.values
    end

    def to_string(value)
      TYPES_INVERTED[value]&.to_s
    end
  end 
end
