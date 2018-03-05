module TermsHelper
  def op_select_options(filter)
    filter_types = TermQuery.filter_types_for_pred(filter.pred_uri)

    options = [["---", nil]]
    options << ["is", :is] if filter_types.include? TermQueryObjectTermFilter
    options += [
      ["=", :eq],
      [">", :gt],
      ["<", :lt]
    ] if filter_types.include? TermQueryNumericFilter
    options << ["range", :range] if filter_types.include? TermQueryRangeFilter

    options_for_select(options, filter.op)
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
end
