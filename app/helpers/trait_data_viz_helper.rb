module TraitDataVizHelper
  def object_pie_chart_data(data)
    data.collect do |datum|
      {
        obj_name: i18n_term_name(datum[:obj]),
        search_path: term_search_results_path(term_query: datum[:term_query]),
        count: datum[:count]
      }
    end
  end
end
