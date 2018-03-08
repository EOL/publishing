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
end
