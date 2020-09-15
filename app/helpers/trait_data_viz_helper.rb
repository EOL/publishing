module TraitDataVizHelper
  def data_viz_data(query, data)
    result = data.collect do |datum|
      name = result_label(query, datum)

      {
        label: name,
        prompt_text: obj_prompt_text(query, datum, name),
        search_path: datum.noclick? ? nil : term_search_results_path(term_query: datum.query.to_params),
        count: datum.count
      }
    end

    result
  end

  def histogram_data(query, data)
    units_text = i18n_term_name(data.units_term)
    buckets = data.buckets.collect do |b|
      {
        min: b.min,
        limit: b.limit,
        count: b.count,
        queryPath: term_search_results_path(term_query: b.query.to_params),
        promptText: hist_prompt_text(query, b, units_text)
      }
    end

    {
      maxBi: data.max_bi,
      bw: data.bw,
      min: data.min,
      maxCount: data.max_count, 
      valueLabel: t("traits.data_viz.hist_value_label", units: units_text),
      yAxisLabel: t("traits.data_viz.num_records_label"),
      buckets: buckets
    }
  end

  def sankey_nodes(nodes)
    nodes.map do |n|
      name = i18n_term_name_for_uri(n.uri)

      {
        id: n.id,
        uri: n.uri,
        name: name,
        fixedValue: n.size,
        axisId: n.axis_id,
        clickable: !n.query_term?,
        searchPath: term_search_results_path(term_query: n.query.to_params),
        promptText: t("traits.data_viz.sankey_node_hover", term_name: name)
      } 
    end
  end

  def sankey_links(links)
    links.map do |l|
      {
        source: l.source.id,
        target: l.target.id,
        value: l.size,
        selected: true,
        names: [i18n_term_name_for_uri(l.source.uri), i18n_term_name_for_uri(l.target.uri)]
      }
    end
  end

  private
  def result_label(query, datum)
    truncate(i18n_term_name(datum.obj), length: 25)
  end

  def obj_prompt_text(query, datum, name)
    prefix = datum.noclick? ? "" : "see_"

    if query.record?
      t("traits.data_viz.#{prefix}n_obj_records", count: datum.count, obj_name: name)
    else
      t("traits.data_viz.#{prefix}n_taxa_with", count: datum.count, obj_name: name)
    end
  end

  def hist_prompt_text(query, bucket, units_text)
    if bucket.count.positive?
      if query.record?
        t("traits.data_viz.show_n_records_between", count: bucket.count, min: bucket.min, limit: bucket.limit, units: units_text)
      else
        t("traits.data_viz.show_n_taxa_between", count: bucket.count, min: bucket.min, limit: bucket.limit, units: units_text)
      end
    else
      ""
    end
  end
end
