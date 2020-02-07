module TraitDataVizHelper
  def object_pie_chart_data(query, data)
    result = data.collect do |datum|
      name = result_label(query, datum)

      {
        label: name,
        prompt_text: prompt_text(query, datum, name),
        search_path: datum.other? ? nil : term_search_results_path(term_query: datum.query.to_params),
        count: datum.count,
        is_other: datum.other?
      }
    end
    puts result
    result
  end

  private
  def result_label(query, datum)
    datum.other? ? t("traits.data_viz.other") : i18n_term_name(datum.obj)
  end

  def prompt_text(query, datum, name)
    if datum.other? 
      if query.record?
        t("traits.data_viz.n_other_records", count: datum.count)
      else
        t("traits.data_viz.n_other_taxa", count: datum.count)
      end
    elsif query.record?
      t("traits.data_viz.see_n_obj_records", count: datum.count, obj_name: name)
    else
      t("traits.data_viz.see_n_taxa_with", count: datum.count, obj_name: name)
    end
  end
end
