module TraitDataVizHelper
  def object_pie_chart_data(data)
    data.collect do |datum|
      obj_name = datum.other? ? "other" : i18n_term_name(datum.obj)

      {
        obj_name: obj_name,
        link_text: t("traits.data_viz.show_n_records_with", obj_name: obj_name, count: datum.count),
        obj_uri: datum.other? ? "other" : datum.obj[:uri],
        search_path: datum.other? ? nil : term_search_results_path(term_query: datum.query.to_params),
        count: datum.count,
        label_key: 'obj_name'
      }
    end
  end
end
