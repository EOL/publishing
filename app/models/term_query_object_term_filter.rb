class TermQueryObjectTermFilter < ActiveRecord::Base
  include TermQueryFilter

  def op
    :is
  end
end
