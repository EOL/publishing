module Reconciliation
  class DataExtensionResult
    def initialize(query)
      @results = query.page_hash.map do |id, page|
        page_results = page_properties(page, query.properties)
        [id, page_results]
      end.to_h
    end

    def to_h
      @results
    end

    private
    def page_properties(page, properties)
      results = {}

      properties.each do |prop|
        prop_results = []
        
        if page.present?
          if prop == Reconciliation::PropertyType::RANK
            prop_results = rank_value_for_page(page)
          elsif prop == Reconciliation::PropertyType::ANCESTOR
            prop_results = ancestor_value_for_page(page) 
          end
        end
        
        results[prop.id] = prop_results
      end

      results
    end

    def rank_value_for_page(page)
      if treat_as = page.rank&.human_treat_as
        [{ 'str' => treat_as }]
      else
        []
      end
    end

    def ancestor_value_for_page(page)
      page.node_ancestors.map do |a|
        Reconciliation::TaxonEntity.new(a.ancestor.page).to_h
      end
    end
  end
end

