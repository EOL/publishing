module TermsHelper
  def op_select_options(filter)
    options_for_select([
      ["---", nil],
      ["is", :is],
      ["=", :eq],
      [">", :gt],
      ["<", :lt],
      ["range", :range]
    ], filter.op)
  end
end
