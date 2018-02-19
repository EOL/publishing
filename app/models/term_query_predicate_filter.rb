class TermQueryPredicateFilter < ActiveRecord::Base
  include TermQueryFilter

  def op
    nil
  end
end
