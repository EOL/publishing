class TermQueryObjectTermFilter < ActiveRecord::Base
  include TermQueryFilter

  validates_presence_of :uri
end
