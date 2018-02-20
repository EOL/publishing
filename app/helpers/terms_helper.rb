module TermsHelper
  def op_select_options(filter)
    options_for_select([
      ["is", :is],
      ["=", :eq],
      [">", :gt],
      ["<", :lt],
      ["range", :range]
    ], filter.op)
  end
end
