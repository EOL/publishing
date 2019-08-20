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

  def filter_display_string(filter)
    parts = []

    if filter.predicate?
      parts << pred_name(filter.pred_uri)

      if filter.object_term?
        parts << ": #{obj_name(filter.obj_uri)}"
      elsif filter.numeric?
        if filter.gt?
          parts << " >= #{filter.num_val1}"
        elsif filter.lt?
          parts << " <= #{filter.num_val2}"
        elsif filter.eq?
          parts << " = #{filter.num_val1}"
        elsif filter.range?
          parts << " in [#{filter.num_val1}, #{filter.num_val2}]"
        end
        parts << " #{units_name(filter.units_uri)}"
      end
    elsif filter.object_term?
      parts << "value: #{obj_name(filter.obj_uri)} "
    end

    if filter.extra_fields?
      parts << " ("
      extra_parts = []

      
      extra_parts << "sex: #{term_name(filter.sex_uri)}" if filter.sex_term?
      extra_parts << "lifestage: #{term_name(filter.lifestage_uri)}" if filter.lifestage_term?
      extra_parts << "statistical method: #{term_name(filter.statistical_method_uri)}" if filter.statistical_method_term?
      extra_parts << "resource: #{filter.resource.name}" if filter.resource

      parts << extra_parts.join(", ")
      parts << ")"
    end

    parts.join("")
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
      display_type = case term_select.type
                     when :predicate
                       "an attribute"
                     when :object_term
                       "a value"
                     else
                       raise TypeError.new("invalid TermSelect type: #{term_select.type}")
                     end
      placeholder = "or select #{display_type}"
    else
      placeholder = "select a child term (optional)"
    end

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
