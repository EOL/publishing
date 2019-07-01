module Breadcrumbs
  class << self
    def default_type
      "vernacular"
    end

    def valid_types
      %w( vernacular canonical )
    end
  end 
end
