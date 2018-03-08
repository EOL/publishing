module TermsHelper
  OP_DISPLAY = {
    :is_any => "match any",
    :is_obj => "is",
    :eq => "=",
    :lt => "<",
    :gt => ">",
    :range => "range"
  }

  def op_select_options(filter)
    filter.valid_ops.map do |op|
      [OP_DISPLAY[op], op]
    end
  end

  def obj_term_options(pred_uri)
    if (!pred_uri.blank?)
      TraitBank::Terms.obj_terms_for_pred(pred_uri).map do |term|
        [term[:name], term[:uri]]
      end
    else
      []
    end
  end

  def units_select_options(units) 
    options_for_select([[units[:name], units[:uri]]], units[:uri])
  end

  def units(pred_uri)
    if (!pred_uri.blank?)
      TraitBank::Terms.unit_term_for_pred(pred_uri)
    else
      nil
    end
  end

  def pred_name(uri)
    TraitBank::Terms.name_for_pred_uri uri
  end

  def obj_name(uri)
    TraitBank::Terms.name_for_obj_uri uri
  end

  def show_error(obj, field) 
    if obj.errors[field].any?
      haml_tag(:div, :class => "filter-error") do
        haml_concat obj.errors[field][0]
      end
    end
  end

  def filter_display_string(filter)
    case filter.op.to_sym
    when :is_any
      is_any_display_string(filter)
    when :is_obj
      is_obj_display_string(filter)
    when :eq
      num_display_string(filter)
    when :lt
      num_display_string(filter)
    when :gt
      num_display_string(filter)
    when :range
      range_display_string(filter)
    end
  end

  private 
    def is_any_display_string(filter)
      pred_name(filter.pred_uri)
    end

    def is_obj_display_string(filter)
      "#{pred_name(filter.pred_uri)} is #{obj_name(filter.obj_uri)}"
    end

    def num_display_string(filter)
      "#{pred_name(filter.pred_uri)} #{OP_DISPLAY[filter.op.to_sym]} #{filter.num_val1}"
    end

    def range_display_string(filter)
      "#{pred_name(filter.pred_uri)} in [#{filter.num_val1}, #{filter.num_val2}]"
    end
end
