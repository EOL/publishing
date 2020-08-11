module TermsHelper
  OP_DISPLAY = {
    :is_any => "any value",
    :is_obj => "is",
    :eq => "=",
    :lt => "<",
    :gt => ">",
    :range => "range"
  }

  def op_select_options(filter)
    options = filter.valid_ops.map do |op|
      [OP_DISPLAY[op], op]
    end
    options_for_select(options, filter.op)
  end

  def units_select_options(filter)
    result = TraitBank::Terms.units_for_pred(filter.pred_uri) # NOTE: this is cached in the class.

    return [] if result == :ordinal # TODO: better handling of this.

    uris = [result[:units_uri]] unless uris
    options = uris.map do |uri|
      [TraitBank::Terms.name_for_uri(uri), uri]
    end

    options_for_select(options, result[:units_uri])
  end

  def pred_name(uri)
    TraitBank::Terms.name_for_uri(uri)
  end

  def obj_name(uri)
    TraitBank::Terms.name_for_uri(uri)
  end

  def units_name(uri)
    TraitBank::Terms.name_for_uri(uri)
  end

  def term_name(uri)
    TraitBank::Terms.name_for_uri(uri)
  end

  def show_error(obj, field)
    if obj.errors[field].any?
      haml_tag(:div, :class => "filter-error") do
        haml_concat obj.errors[field][0]
      end
    end
  end

  def filter_obj_name(filter)
    raise TypeError.new("filter does not have an object") if !filter.object?
    filter.object_term? ? i18n_term_name_for_uri(filter.obj_uri) : filter.obj_clade.canonical
  end

  def filter_display_string(filter)
    parts = []
    prefix = "traits.search.filter_display."

    if filter.predicate?
      pred_name = i18n_term_name_for_uri(filter.pred_uri)

      if filter.object?
        parts << t("#{prefix}pred_obj", pred: pred_name, obj: filter_obj_name(filter))
      elsif filter.numeric?
        units = i18n_term_name_for_uri(filter.units_uri)

        if filter.gt?
          parts << t("#{prefix}gte", pred: pred_name, num_val: filter.num_val1, units: units)
        elsif filter.lt?
          parts << t("#{prefix}lte", pred: pred_name, num_val: filter.num_val2, units: units)
        elsif filter.eq?
          parts << t("#{prefix}eq", pred: pred_name, num_val: filter.num_val1, units: units)
        elsif filter.range?
          parts << t("#{prefix}range", pred: pred_name, num_val1: filter.num_val1, num_val2: filter.num_val2, units: units)
        end
      else
        parts << t("#{prefix}pred_only", pred: pred_name)
      end
    elsif filter.object?
      parts << t("#{prefix}obj_only", obj: filter_obj_name(filter))
    end

    if filter.extra_fields?
      parts << t("#{prefix}sex", value: i18n_term_name_for_uri(filter.sex_uri)) if filter.sex_term?
      parts << t("#{prefix}lifestage", value: i18n_term_name_for_uri(filter.lifestage_uri)) if filter.lifestage_term?
      parts << t("#{prefix}statistical_method", value: i18n_term_name_for_uri(filter.statistical_method_uri)) if filter.statistical_method_term?
      parts << t("#{prefix}resource", value: filter.resource.name) if filter.resource
    end

    sanitize(parts.join("<br>"), tags: %w( br ))
  end

  def term_query_display_string(tq)
    filter_part = tq.filters.map do |f|
      filter_display_string(f)
    end.join(', ')

    clade_part = tq.clade ? 
      "clade: #{tq.clade.native_node&.canonical_form}, " : 
      ""

    "#{tq.record? ? "Records" : "Taxa"} with #{clade_part}#{filter_part}"
  end

  def term_options_for_select(term_select)
    term_array = term_select.terms.collect do |term|
      [term[:name], term[:uri]]
    end

    if term_select.top_level?
      placeholder_key = case term_select.type
                        when :predicate
                          "top_level.predicate"
                        when :object_term
                          "top_level.object_term"
                        else
                          raise TypeError.new("invalid TermSelect type: #{term_select.type}")
                        end
    else
      placeholder_key = "child_term"
    end

    placeholder = I18n.t("traits.search.select.#{placeholder_key}")

    options_for_select([[placeholder, nil]].concat(term_array), term_select.selected_uri)
  end

  def nested_term_selects(form, type)
    type_str = "#{type}_term_selects"
    selects = form.object.send(type_str)
    nested_term_selects_helper(form, selects, type_str)
  end

  private
    def is_any_display_string(filter)
      pred_name(filter.pred_uri)
    end

    def is_obj_display_string(filter)
      "#{pred_name(filter.pred_uri)}:  #{obj_name(filter.obj_uri)}"
    end

    def num_display_string(filter)
      "#{pred_name(filter.pred_uri)} #{OP_DISPLAY[filter.op.to_sym]} #{filter.num_val1} #{units_name(filter.units_uri)}"
    end

    def range_display_string(filter)
      "#{pred_name(filter.pred_uri)} in [#{filter.num_val1}, #{filter.num_val2}] #{units_name(filter.units_uri)}"
    end

    def nested_term_selects_helper(form, selects, type_str)
      result = nil

      if selects.any?
        first = selects.shift
        form.fields_for type_str, first do |select_form|
          inner = nested_term_selects_helper(form, selects, type_str)
          result = render(partial: "traits/term_select", locals: { form: select_form, inner: inner})
        end
      end

      result
    end
end
