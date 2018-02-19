class TermQueryObjectTermFilter < ActiveRecord::Base
  include TermQueryFilter

  validates_presence_of :uri

  def op
    :is
  end
end
