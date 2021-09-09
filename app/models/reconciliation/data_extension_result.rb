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
        type = prop.type
        settings = prop.settings

        if page.present?
          if type == Reconciliation::PropertyType::RANK
            prop_results = rank_value_for_page(page)
          elsif type == Reconciliation::PropertyType::ANCESTOR
            prop_results = ancestor_value_for_page(page, settings) 
          elsif type == Reconciliation::PropertyType::EXTINCTION_STATUS
            prop_results = extinction_status_value_for_page(page)
          elsif type == Reconciliation::PropertyType::CONSERVATION_STATUS
            prop_results = conservation_status_value_for_page(page)
          end
        end
        
        results[type.id] = prop_results
      end

      results
    end

    def conservation_status_value_for_page(page)
      decorated = BriefSummary::PageDecorator.new(page, nil)
      trait = decorated.first_trait_for_predicate(TermNode.find_by_alias('conservation_status'))

      value = trait&.object_term&.i18n_name

      if value
        [{ 'str' => value }]
      else
        []
      end
    end

    def extinction_status_value_for_page(page)
      str = BriefSummary::PageDecorator.new(page, nil).extinct? ?
        'extinct' :
        'extant'

      [{ 'str' => str }]
    end

    def rank_value_for_page(page)
      if treat_as = page.rank&.human_treat_as
        [{ 'str' => treat_as }]
      else
        []
      end
    end

    def ancestor_value_for_page(page, settings)
      node_ancestors = page.node_ancestors.reorder(depth: 'desc')

      limit = settings.find do |setting| 
        setting.type == Reconciliation::PropertySettingType::LIMIT
      end&.value&.to_i

      if limit && limit > 0
        node_ancestors = node_ancestors.limit(limit)
      end

      node_ancestors.map do |a|
        Reconciliation::TaxonEntity.new(a.ancestor.page).to_h
      end
    end
  end
end

