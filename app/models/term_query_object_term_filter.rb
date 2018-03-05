class TermQueryObjectTermFilter < ActiveRecord::Base
  include TermQueryFilter

  validates_presence_of :obj_uri

  def op
    :is
  end
end
