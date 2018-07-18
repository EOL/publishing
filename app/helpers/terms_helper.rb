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
    whn :lt
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
      "#{pred_name(filter.pred_uri)}:  #{obj_name(filter.obj_uri)}"
    end

    def num_display_string(filter)
      "#{pred_name(filter.pred_uri)} #{OP_DISPLAY[filter.op.to_sym]} #{filter.num_val1} #{units_name(filter.units_uri)}"
    end

    def range_display_string(filter)
      "#{pred_name(filter.pred_uri)} in [#{filter.num_val1}, #{filter.num_val2}] #{units_name(filter.units_uri)}"
    end
end
