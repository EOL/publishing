module Reconciliation
  class TaxonEntity
    def initialize(page) 
      raise ArgumentError, "page can't be nil" if page.nil?
      @page = page
    end

    def to_h
      @h ||= {
        'id' => "pages/#{@page.id}",
        'name' => @page.scientific_name_string
      }
    end
  end
end
